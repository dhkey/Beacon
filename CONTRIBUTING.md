# Contributing to Beacon

Thank you for helping improve Beacon. Bug reports, feature suggestions, documentation updates, tests, and code changes are welcome.

## Before you start

- Search the [existing issues](https://github.com/dhkey/Beacon/issues) before opening a new one.
- For a bug, include your macOS version, Beacon version, steps to reproduce it, and the behavior you expected.
- For a substantial feature or behavior change, open an issue first so the approach can be discussed before implementation.

## Development requirements

- macOS 26.0 or later
- Xcode 26 or later
- Git

Beacon has no third-party dependencies. Clone the repository and open `Beacon.xcodeproj` in Xcode:

```sh
git clone https://github.com/dhkey/Beacon.git
cd Beacon
open Beacon.xcodeproj
```

Select the **Beacon** scheme and run the project, or build it from the command line:

```sh
xcodebuild -project Beacon.xcodeproj -scheme Beacon -configuration Debug build
```

## Making a change

1. Fork the repository and create a focused branch from `main`:

   ```sh
   git switch main
   git pull --ff-only origin main
   git switch -c fix/short-description
   ```

2. Make the smallest complete change that solves the problem.
3. Follow the existing Swift and SwiftUI style in the surrounding code.
4. Add or update tests when behavior changes.
5. Avoid committing build products, local Xcode user data, or unrelated formatting changes.

## Testing

Run the test suite before opening a pull request:

```sh
xcodebuild test \
  -project Beacon.xcodeproj \
  -scheme Beacon \
  -destination 'platform=macOS'
```

For user-interface changes, also verify the relevant behavior manually, including keyboard navigation and the global shortcut when applicable.

## Pull requests

- Give the pull request a clear title and explain what changed and why.
- Link any related issue.
- Include screenshots or a short recording for visible interface changes.
- Keep each pull request focused on one concern.
- Confirm that the project builds and tests pass locally.

GitHub Actions builds and tests every pull request targeting `main`. A maintainer creates releases after changes are merged; contributors do not need to create release tags.
