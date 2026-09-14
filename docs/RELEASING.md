# Release preparation

## Source releases

1. Run `zsh scripts/check.sh` on Apple silicon and Intel macOS runners.
2. Run `zsh scripts/package-installer.sh` and `zsh scripts/check-package.sh`.
3. Run `zsh scripts/package-source.sh`. Extract the archive into a fresh directory and run its checks.
4. Review the archive for credentials, device identifiers, local paths, generated binaries, and filesystem metadata.
5. Update the changelog and record hardware validation below before tagging a release.

`Info.plist` is the version source for the app, packaged driver, installer, and archive. Local packaging does not install or publish anything. Every push to `main` that passes the macOS check matrix publishes a universal `Hush.pkg` and SHA-256 checksum in its own GitHub Release. Releases use unique workflow-run tags, so repeated app versions do not overwrite earlier installers. Only the current main commit is marked latest; the README points to its stable asset URL. Pull requests never publish.

## Binary releases

Local build scripts use ad-hoc signatures. A consumer binary release needs a maintainer-owned signing and notarization process, with signatures verified on the app, nested helper, driver, and installer. Signing credentials must never enter the source tree. The automated download pipeline currently publishes experimental, ad-hoc-signed packages; Developer ID signing and notarization are not implemented.

The integrated uninstaller currently uses the deprecated `AuthorizationExecuteWithPrivileges` API. Modernizing that authorization mechanism and validating it on supported macOS versions remain binary-release work. Source availability does not imply production readiness.

## Hardware validation record

Automated checks cover routing policy, driver custom-property registration and types, and an unavailable driver’s empty ready UID. They do not establish successful installation, audio playback, or uninstall behavior.

Before a binary release, record OS version, architecture, hardware, result, and date for:

- Clean install and upgrade; exactly one Hush app in Applications.
- Login, reboot, audio-service restart, and opening/closing the settings window.
- Selecting both the physical monitor and its Hush output; stable selection over time.
- Slider, volume keys, mute, and 100% unity gain using controlled audio.
- USB/Bluetooth connection, unplug fallback, reconnect, and sleep/wake.
- Uninstall cancellation, authorization cancellation, complete removal, optional settings deletion, and audio restoration failure with recovery.
- Separate user sessions and reinstall after removal.

Current local observations: playback through an HDMI monitor was restored after restarting the agent in 0.3.1. The 0.3.2 UID correction builds and passes automated checks; its installed hardware behavior and the integrated privileged uninstall are not yet end-to-end verified. Do not label them verified based on preflight alone.
