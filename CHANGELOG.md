# Changelog

## Unreleased

- Cleans up source distribution, documentation, obsolete standalone-uninstaller files, and packaging checks.
- Uses one version source for all packaged components.

## 0.3.3

- Fixes selecting a monitor’s Hush output immediately switching back to previously selected speakers or headphones.
- Resolves the virtual output to its ready physical destination, including at startup, while retaining hotplug priorities.
- Preserves the active proxy volume when adopting the route and avoids saving it under a different output’s preferences.
- Adds regression coverage for direct proxy selection, startup, stale destinations, manual speaker selection, and headphone hotplug.

## 0.3.2

- Uses stable output UIDs for cross-process driver readiness and uninstall restoration instead of comparing numeric device handles.
- Adds registration and unavailable-output checks for the ready-UID property.

## 0.3.1

- Adds a settings window with integrated uninstall and administrator authorization.
- Keeps login startup silent and removes the separate uninstaller during upgrades.

## 0.3.0

- Replaces the extra volume slider with a HAL output controlled by macOS volume controls.
- Adds routing rules, readiness checks, per-output settings, and login startup.
- Adds an installer and original app artwork.
- Adapts Proxy Audio Device with preserved third-party notices.
