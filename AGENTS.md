# Project Guidelines

## Project Overview

- VisionTrackMVVM is an independent iOS technical learning portfolio project.
- Use simulated vision records; do not use real patient data.

## Architecture

- Use SwiftUI with Feature-Based MVVM.
- Use the Observation framework to manage UI state.
- Views own presentation and localized display.
- ViewModels own state and coordinate operations.
- Models must remain independent of UI and display language.
- Introduce repositories, services, and protocols incrementally when concrete requirements justify them.
- Avoid overengineering and unnecessary third-party packages.

## Localization

- English (`en`) is the development language; support Traditional Chinese (`zh-Hant`).
- Maintain translations in `Localizable.xcstrings`; do not create duplicate catalogs for the same table.
- Do not hardcode translated display strings in ViewModels.
- Format dates and numbers according to the current Locale.

## Git Workflow

- Before starting any work, inspect Git status and the current branch.
- Prefer `feature/*` branches for new features when authorized by the user.
- Never overwrite or delete uncommitted changes without explicit authorization.
- Stage and commit only files relevant to the authorized task.
- Use Conventional Commits for commit messages.
- Without explicit user authorization, do not run `git add`, `git commit`, `git merge`, `git rebase`, `git reset`, `git clean`, `git push`, or any operation that changes Git history.
- Any Git write operation, including switching or creating branches and changing the index, requires explicit user authorization.
- Read-only Git inspections and `git diff --check` are allowed.

## Development Workflow

- Inspect the existing architecture before making changes.
- Present a plan and the expected file changes before implementation.
- Implement only the scope approved for the current task.
- After changes, run available builds and tests appropriate to the change. For documentation-only or ignore-rule changes, validate the files and explain why builds and tests were not run.
- Report design rationale, changed files, verification results, and material risks or limitations.
- Never claim that tests passed unless they were actually executed and passed.

## Testing

- Prioritize unit tests for ViewModels and business logic, using Swift Testing.
- Add UI tests for important user flows, using XCTest.
- When implementing APIs or data synchronization, cover errors, retries, and deduplication.
- Provide test results after completing each feature.

## Security

- Never commit API keys, tokens, certificates, passwords, or real medical data.
- Use simulated or de-identified test data; vision records in this project must be simulated.
- Do not write sensitive data to logs.

## Communication

- Obtain explicit user authorization before any Git write operation.
