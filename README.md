# VisionTrackMVVM

VisionTrackMVVM is an independent iOS learning and portfolio project built with SwiftUI. It records **simulated decimal visual acuity values**, persists them locally, and displays their history. It does not measure eyesight or provide medical diagnoses. Use simulated records, not real patient data.

## Features and architecture

- **Dashboard:** shows the latest record, with separate empty, loaded, and read-failure states.
- **Record entry:** validates left/right input, supports cancellation and save retries, and refreshes the Dashboard after a successful save. A retry preserves the record's identity while its effective values remain unchanged.
- **Persistence:** SwiftData retains records across App process launches. Storage initialization failures show a retry action without deleting data or silently switching to in-memory storage.
- **History:** lists records by measurement time descending, then insertion order descending. Selecting a row opens a read-only detail snapshot.
- **Localization:** English and Traditional Chinese, with dates and numbers formatted for the current Locale.

The App uses Feature-Based MVVM and Observation. Views handle presentation and localized display; ViewModels coordinate state through an injected, synchronous, MainActor-isolated repository protocol. The Domain Model remains a struct, separate from the SwiftData entity.

The App root owns startup state, which retains the ModelContainer and SwiftData repository. Dashboard and entry share that repository; History receives the same instance. ViewModels do not access ModelContext. An in-memory repository remains available for tests and previews. There are no third-party packages, remote APIs, CloudKit synchronization, editing, or deletion features.

## Technology stack

| Area | Implementation |
| --- | --- |
| Language | Swift 5 language mode (`SWIFT_VERSION = 5.0`) |
| UI and state | SwiftUI, Observation |
| Concurrency | App target defaults to MainActor isolation; Approachable Concurrency enabled |
| Local persistence | SwiftData behind a repository protocol |
| Unit and integration tests | Swift Testing |
| UI tests | XCTest |
| Localization | One `Localizable.xcstrings` catalog, `en` and `zh-Hant` |
| Automation | Bash build/test script and GitHub Actions workflow |
| Minimum deployment target | iOS 26.0 |

Xcode 27.2 is the validated toolchain; its version is distinct from the project's Swift language mode. Swift 6 language mode has not been validated.

## Requirements

The local validation environment is **Xcode 27.2 (27B52)** with **iPhone 18 Pro / iOS 27.2 Simulator**. Other combinations may work but are not covered by this baseline.

Install full Xcode and the required Simulator runtime. No Homebrew packages, Fastlane, third-party dependencies, Apple Developer signing certificates, or user-provided secrets are required for the Simulator commands. The script uses macOS Bash 3.2 and system Ruby for JSON parsing. The workflow additionally uses Python 3 for diagnostic collection.

- Project: `VisionTrackMVVM.xcodeproj`
- Shared scheme: `VisionTrackMVVM`
- Test targets: `VisionTrackMVVMTests` and `VisionTrackMVVMUITests`

Open the project in Xcode to run the App interactively. Normal App launches use a persistent store inside the App's Application Support directory. The Simulator automation commands below disable code signing.

## Local build and test

From the repository root:

```bash
./scripts/ios-ci.sh unit
./scripts/ios-ci.sh ui
./scripts/ios-ci.sh release
```

| Mode | Action |
| --- | --- |
| `unit` | Builds Debug for Simulator and runs only `VisionTrackMVVMTests` |
| `ui` | Builds Debug for Simulator and runs only `VisionTrackMVVMUITests`, with parallel testing disabled |
| `release` | Builds Release for Simulator; does not run tests, archive, or deploy |

The script locates the project relative to itself, so its operation does not depend on the caller's working directory. It queries available runtimes and devices, resolves a unique UDID, and fails rather than silently selecting a different environment.

| Environment variable | Behavior |
| --- | --- |
| `DEVELOPER_DIR` | Uses the supplied Xcode developer directory; otherwise uses the active selection |
| `IOS_CI_DEVICE` | Defaults to `iPhone 18 Pro` |
| `IOS_CI_OS` | Defaults to `27.2` |

For example, to explicitly request the validated device/runtime:

```bash
IOS_CI_DEVICE="iPhone 18 Pro" IOS_CI_OS="27.2" ./scripts/ios-ci.sh unit
```

After initial tool and project checks pass, each invocation creates a fresh `/private/tmp/visiontrack-ios-ci.<random>` directory. Its path is printed at startup and exit. It contains:

- `environment.log`: mode, Xcode/SDK information, requested/resolved Simulator, and Git HEAD when available.
- `xcodebuild.log`: full build/test output, also streamed to the terminal.
- `DerivedData/`: isolated build products.
- `unit.xcresult` or `ui.xcresult`: test results, when generated.
- Simulator inventory and selection diagnostics for troubleshooting.

The script uses `CODE_SIGNING_ALLOWED=NO`. It also sets `SWIFT_EMIT_LOC_STRINGS=NO` to disable Swift localization extraction; existing committed String Catalog translations still compile into the App. Source/catalog consistency was checked during local validation in an isolated project copy.

Failures return a nonzero exit code and retain available diagnostics. `PIPESTATUS` preserves the original xcodebuild failure through `tee`; a logging failure also fails an otherwise successful command. There is no automatic retry or cleanup of previous results, App stores, or Simulator data.

## Test isolation

UI tests launch the App through `makeUITestApplication`, which supplies a UUID Store ID using `VISIONTRACK_UI_TEST_STORE_ID`. The Debug App validates that ID and maps it to a separate test-store directory inside its sandbox. Each independent test uses its own ID; process-restart tests deliberately reuse the same ID. Invalid IDs fail instead of falling back to the production store.

Hosted Unit Tests use an in-memory startup container in Debug. Repository integration tests use isolated in-memory containers or test-specific temporary disk stores. Production Release builds exclude these Debug test-routing branches. The `release` script mode only builds the App; it does not launch it.

## GitHub Actions workflow

The workflow is defined in [ios-ci.yml](.github/workflows/ios-ci.yml) and calls the same [local script](scripts/ios-ci.sh).

| Event | `debug-unit` | `ui-regression` | `release-build` |
| --- | --- | --- | --- |
| Pull request targeting `main` | Run | Skip | Skip |
| Push to `main` | Run | Run | Run |
| `workflow_dispatch` | Run | Run | Run |
| Timeout | 20 minutes | 30 minutes | 20 minutes |

Each job uses its own `xcode-27` runner and build outputs. The workflow explicitly selects `/Applications/Xcode_27.2.app/Contents/Developer`, verifies Xcode 27.2, and requests iPhone 18 Pro / iOS 27.2. Missing Xcode, runtime, or device causes failure. The first remote execution must confirm the actual Xcode build number and runner image; these are not assumed to match the local installation.

Only newer runs for the same PR cancel older PR runs. Main pushes and manual runs use separate groups. Jobs do not share DerivedData and have no cache or automatic failure retry.

The workflow records selected runner image, OS, architecture, and Xcode details without dumping the environment. It parses the script's actual output directory, validates the path and file types, rejects symbolic links, and stages only `environment.log`, `xcodebuild.log`, and the test xcresult under a unique `RUNNER_TEMP` directory. Collection and upload are attempted after failure when diagnostics are available; missing diagnostics produce an explicit warning, not a dummy artifact.

Artifacts are retained for **7 days**. An upload failure cannot turn a failed build/test into success. Cancellation, job timeout, or runner loss can prevent diagnostic upload.

## Local validation baseline

These are **completed local results**, not evidence of a successful remote Actions run:

| Check | Result |
| --- | --- |
| Debug Simulator build/test compilation | Passed |
| Unit Tests | 55 passed, 0 failed, 0 skipped |
| UI Tests | 23 executions passed, 0 failed, 0 skipped |
| Release Simulator build | Passed |
| Milestone 04 manual acceptance | 22/22 passed, including VoiceOver and Dynamic Type checks |

The UI count includes launch-test executions for different UI configurations; it does not mean 23 independent test methods. The current suite has 16 named methods, including a launch test executed in eight configurations.

The script was validated in an isolated copy whose project files and script matched the working tree byte for byte. Error-path checks covered invalid arguments, missing tools/runtime, and propagation of a simulated xcodebuild exit code of 65.

## Troubleshooting

**Xcode cannot be found or the wrong installation is selected**

Inspect the active configuration:

```bash
xcode-select -p
printf '%s\n' "${DEVELOPER_DIR:-not set}"
xcodebuild -version
```

Set `DEVELOPER_DIR` to the `Contents/Developer` directory of an installed full Xcode App, then rerun the intended command. The local script respects that value; the workflow deliberately requires its configured Xcode 27.2 path. Do not substitute another toolchain silently.

**Simulator runtime or device is unavailable**

```bash
xcrun simctl list runtimes
xcrun simctl list devices available
```

The script prints available candidates if the requested destination is missing or ambiguous. Confirm the installed runtime, or explicitly select an available combination with `IOS_CI_DEVICE` and `IOS_CI_OS`. A different combination needs its own validation. The script does not download runtimes or create/delete devices.

**Build or test failure**

Read the paths printed at exit. Start with `environment.log` to verify the toolchain and destination, then inspect `xcodebuild.log` for the first relevant error. Open the generated `.xcresult` bundle in Xcode to inspect failures, screenshots, and test attachments. If execution stopped early, some output files may not exist.

Keep the original nonzero exit code and diagnostics. Investigate whether the failure is in the script, product, test, or Simulator environment before rerunning. Do not hide the first failure with automatic retries or delete SwiftData stores as a general troubleshooting step.

**Known warning**

UI test logs have reported `Invalid frame dimension (negative or non-finite)`. Its source remains unconfirmed. Milestone 04 manual checks did not find a corresponding visible defect; this does not establish that the warning is harmless.

## CI verification status

| Area | Status |
| --- | --- |
| Local script | Validated |
| Workflow YAML / Shell static review | Validated |
| Remote GitHub Actions PR run | Not Yet Verified |
| Remote main push run | Not Yet Verified |
| Runner Xcode / Simulator availability | Pending Remote Validation |
| Artifact upload | Pending Remote Validation |

No Git remote is configured for the local checkout at this documentation stage. Workflow syntax and local simulations do not prove remote CI success. Future status updates should cite an actual Actions run URL, commit SHA, selected toolchain/runtime, job logs, and artifacts. This repository does not yet publish a CI success badge.

## Security and scope

- Use simulated data only. Do not commit secrets, certificates, provisioning profiles, personal `xcuserdata`, or SwiftData stores.
- Workflow permissions are limited to `contents: read`. Checkout does not persist credentials, and official checkout/upload actions are pinned to full commit SHAs.
- There are no user-provided CI secrets or Apple signing assets. CI does not archive, publish releases, use TestFlight, or deploy.
- UI test stores are isolated by ID. Artifacts exclude full DerivedData, Simulator sandboxes, personal settings, and production data; test-result attachments can contain simulated screenshots.
- Device testing, Swift 6 language mode, and large-history performance remain outside the validated baseline.
