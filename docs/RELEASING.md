# Publishing Hush

## Source repository

1. Publish only this project directory, never its parent workspace. Do not include `build/`, `dist/`, diagnostics, or local preferences.
2. Confirm the MIT license and project name fit the intended release. The name has not been checked for trademark or app-store availability.
3. Create the public repository, enable private vulnerability reporting, and add a verified maintainer contact to SECURITY.md.
4. Run `zsh scripts/check.sh` and `zsh scripts/package-source.sh`. Inspect the generated source archive.
5. Confirm GitHub Actions passes after pushing. Record hardware smoke tests using CONTRIBUTING.md.
6. Review version fields in Info.plist and CHANGELOG.md before creating a tag. Describe known limitations in release notes.

## Binary releases

Local builds are ad-hoc signed. Before offering binaries to general users, configure a maintainer-owned bundle identifier and Developer ID signing, notarize with Apple, and verify the downloaded artifact on a clean Mac. Keep signing credentials in the hosting service’s secret store, never in this repository.

The build currently targets the host architecture. Produce and test a universal binary or clearly label separate Apple Silicon and Intel builds. Do not label an architecture or older macOS release as tested based only on cross-compilation. Binary signing, notarization, automatic updates, and release uploads are not automated here.

## Earlier local prototype

This source version uses `local.hush.Hush`. Early private builds used a different identity and login launcher. Before migrating one of those installations, quit the old app and disable its old login launcher to avoid two audio controllers. Existing audio permissions and volume preferences do not automatically migrate across bundle identifiers. Public install scripts intentionally do not alter unrelated apps or launch agents.
