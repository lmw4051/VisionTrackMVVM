#!/bin/bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ios-ci.sh {unit|ui|release}
  unit     Build Debug and run VisionTrackMVVMTests
  ui       Build Debug and run VisionTrackMVVMUITests serially
  release  Build Release for Simulator only

Environment:
  DEVELOPER_DIR  Optional Xcode developer directory
  IOS_CI_DEVICE  Simulator name (default: iPhone 18 Pro)
  IOS_CI_OS      iOS runtime version (default: 27.2)
USAGE
}

if [[ $# -eq 1 && ( $1 == --help || $1 == -h || $1 == help ) ]]; then
    usage
    exit 0
fi
if [[ $# -ne 1 ]]; then
    usage >&2
    exit 64
fi
mode=$1
case "$mode" in
    unit|ui|release) ;;
    *) usage >&2; exit 64 ;;
esac

for tool in xcodebuild xcode-select xcrun mktemp tee; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool not found: %s\n' "$tool" >&2
        exit 69
    fi
done
if [[ ! -x /usr/bin/ruby ]]; then
    printf 'Required tool not found: macOS system Ruby (for simctl JSON)\n' >&2
    exit 69
fi

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$root"
project=VisionTrackMVVM.xcodeproj
scheme=VisionTrackMVVM
if [[ ! -f "$project/project.pbxproj" || ! -f "$project/xcshareddata/xcschemes/$scheme.xcscheme" ]]; then
    printf 'Project or shared scheme not found in %s\n' "$root" >&2
    exit 66
fi

device=${IOS_CI_DEVICE:-iPhone 18 Pro}
os=${IOS_CI_OS:-27.2}
# Use a fresh directory outside the checkout. Do not accept arbitrary output paths.
output=$(mktemp -d /private/tmp/visiontrack-ios-ci.XXXXXXXX)
log="$output/xcodebuild.log"
preflight="$output/environment.log"
result="$output/$mode.xcresult"

finish() {
    local status=$?
    printf '\nFinished: %s (exit %s)\n' "$mode" "$status"
    printf 'Environment log: %s\n' "$preflight"
    if [[ -f "$log" ]]; then printf 'Build/test log: %s\n' "$log"; fi
    if [[ -d "$result" ]]; then printf 'Result bundle: %s\n' "$result"; fi
}
trap finish EXIT

describe_environment() {
    printf 'Starting: %s (%s)\n' "$mode" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'Requested Simulator: %s / iOS %s\n' "$device" "$os"
    printf 'Output: %s\n' "$output"
    printf 'xcode-select -p: '
    xcode-select -p || return $?
    xcodebuild -version || return $?
    if command -v git >/dev/null 2>&1 && commit=$(git rev-parse --verify HEAD 2>/dev/null); then
        printf 'Git HEAD: %s\n' "$commit"
    fi
}
describe_environment 2>&1 | tee "$preflight"

# Run the SDK check explicitly so its failure cannot be hidden by logging.
xcodebuild -version -sdk iphonesimulator SDKVersion 2>&1 | tee -a "$preflight"
xcrun simctl list -j >"$output/simctl.json" 2>>"$preflight" || {
    printf 'Unable to query CoreSimulator; see %s\n' "$preflight" >&2
    exit 69
}

# Use runtime identifiers from simctl rather than guessing them from version strings.
udid=$(/usr/bin/ruby -rjson - "$output/simctl.json" "$device" "$os" 2>"$output/simulator-selection.log" <<'RUBY'
inventory = JSON.parse(File.read(ARGV[0]))
name, version = ARGV[1, 2]
candidates = inventory.fetch("runtimes").flat_map do |runtime|
  next [] unless runtime.fetch("identifier").start_with?("com.apple.CoreSimulator.SimRuntime.iOS-") &&
                 runtime["isAvailable"] == true
  inventory.fetch("devices").fetch(runtime.fetch("identifier"), []).select { |device| device["isAvailable"] == true }.map do |device|
    [runtime.fetch("version"), device.fetch("name"), device.fetch("udid")]
  end
end
matches = candidates.select { |os, model, _| os == version && model == name }
if matches.length != 1
  warn(matches.empty? ? "Requested Simulator is unavailable: #{name} / iOS #{version}" :
                        "Requested Simulator is ambiguous: #{name} / iOS #{version}")
  warn "Available iOS Simulators (version | name | UDID):"
  candidates.sort.each { |entry| warn "  #{entry.join(' | ')}" }
  exit 69
end
puts matches.first.last
RUBY
) || {
    selection_status=$?
    tee -a "$preflight" <"$output/simulator-selection.log" >&2
    exit "$selection_status"
}
printf 'Selected Simulator: %s / iOS %s (%s)\n' "$device" "$os" "$udid" | tee -a "$preflight"

configuration=Debug
action=test
test_options=()
case "$mode" in
    unit) test_options=(-only-testing:VisionTrackMVVMTests -resultBundlePath "$result") ;;
    ui) test_options=(-only-testing:VisionTrackMVVMUITests -parallel-testing-enabled NO -resultBundlePath "$result") ;;
    release) configuration=Release; action=build ;;
esac

# Bash 3.2 treats an empty array as unset under nounset.
set +e
xcodebuild -project "$project" -scheme "$scheme" -configuration "$configuration" \
    -sdk iphonesimulator -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$output/DerivedData" \
    CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=NO \
    ${test_options[@]+"${test_options[@]}"} "$action" 2>&1 | tee "$log"
statuses=("${PIPESTATUS[@]}")
set -e
if [[ ${statuses[1]} -ne 0 ]]; then
    printf 'Could not save the full xcodebuild log: %s\n' "$log" >&2
fi
if [[ ${statuses[0]} -ne 0 ]]; then
    exit "${statuses[0]}"
fi
exit "${statuses[1]}"
