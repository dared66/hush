# Contributing

Use macOS 14.4 or newer with Xcode Command Line Tools. Run `zsh scripts/check.sh` before submitting a change. It builds the app and driver and runs routing tests with sanitizers plus driver property checks, without installing a driver or requiring administrator access.

The Objective-C app is in `src/main.m`; routing policy is in `src/RoutePolicy.h`. The adapted HAL driver is in `driver/`, installation scripts in `installer/`, and built-in removal helpers in `uninstaller/`. The icon is generated from `scripts/render-icons.swift` with `zsh scripts/build-icons.sh`.

Keep audio routing independent of the settings window. Use stable device UIDs across process boundaries; numeric Core Audio IDs are local handles. Add regression coverage for routing changes and distinguish synthetic tests from actual hardware validation. Preserve third-party notices and document changes to vendored code.

Installer and uninstaller changes execute with administrator privileges. Keep removal paths explicit, restore physical audio before deleting the driver, and test cancellation and failure recovery. Describe the hardware and macOS versions actually tested in your pull request. See [release validation](docs/RELEASING.md).
