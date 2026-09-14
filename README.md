<p align="center"><img src="assets/Hush.png" width="112" alt="Hush icon"></p>
<h1 align="center">Hush</h1>
<p align="center">Your Mac’s volume controls, for your monitor.</p>

Monitor volume grayed out on your Mac? Hush lets you adjust it with the volume keys and the macOS Sound slider. No extra menu-bar slider.

<p align="center"><img src="assets/screenshots/macos-volume-control.png" width="480" alt="macOS Sound panel with DELL S3221QS (Hush) selected and the system volume slider available."></p>

## Install

Requires **macOS 14.4 or newer**.

1. **[Download Hush.pkg](https://github.com/dared66/hush/releases/latest/download/Hush.pkg)** and open it.
2. If macOS blocks it, follow [If macOS blocks the installer](#if-macos-blocks-the-installer) below.
3. Follow the installer prompts and enter your Mac administrator password when asked.
4. Hush starts automatically, including after you restart your Mac.

Pause playback or calls before installing—audio restarts briefly.

**One installer for Apple silicon and Intel.** New installers are published in [Releases](https://github.com/dared66/hush/releases) after every push to `main` passes checks.

Hush is **free, open source, and currently unnotarized**. You do not need to pay, join Apple’s Developer Program, or build from source to use the installer.

### If macOS blocks the installer

For an “unidentified developer” or “Apple cannot check it” warning:

1. Try opening **Hush.pkg** once, then dismiss the warning.
2. Open **System Settings → Privacy & Security**.
3. Scroll to Security and click **Open Anyway** for Hush.
4. Confirm **Open**, then continue installation.

Only approve a download you trust from [this repository’s Releases](https://github.com/dared66/hush/releases). This approves the specific download; you do not need to disable Gatekeeper globally or run Terminal commands. If macOS reports malware or a damaged file, stop rather than treating it as the same warning. A managed work or school Mac may not allow an override. See [Apple’s instructions](https://support.apple.com/en-us/102445).

### What works without notarization?

- **Download and install:** the ready-made installer is available, but macOS may require the approval above.
- **Volume, mute, and startup:** notarization is not a feature unlock. Once the app and driver are allowed to run, its absence does not itself disable these features or the built-in uninstaller.
- **Updates:** a new download may require approval again. We cannot promise a single approval forever.
- **Installation reliability:** we have not yet verified the GitHub-downloaded package’s complete installation, driver loading, and uninstall on a clean Mac. Automated checks do not establish that every Mac will accept it.

### Why isn’t Hush notarized?

Hush does not currently fund a paid Apple Developer Program membership. Apple lists membership at **US$99 per year**, with local pricing where available and fee waivers for some eligible organizations. This is a developer expense, not a fee Hush users need to pay. [Apple membership details](https://developer.apple.com/programs/enroll/).

The app and driver have **ad-hoc signatures**, not an Apple-issued Developer ID signature; the installer package is not Developer ID signed either. Ad-hoc signing does not verify the publisher’s identity to Apple. Notarization adds Apple’s automated malware check; it is not a guarantee of audio reliability.

Developer ID signing and notarization would remove the normal unidentified-developer workaround. Administrator authorization would still be needed to install Hush’s system-wide audio driver. For now, expect the extra approval step and the experimental limitations above.

## Use

1. Open **Control Center → Sound**.
2. Select your monitor’s **(Hush)** output, as shown above.
3. Adjust volume with your keyboard or the Sound slider. Mute works too.

Hush automatically handles supported output changes. Headphones and speakers with their own native volume controls use their normal output. Open **Hush** from Applications for its settings window; you can close the window and keep using volume control.

At 100%, Hush sends audio without attenuation. Your monitor’s own volume setting still affects how loud it gets.

## Uninstall

Open **Hush** from Applications and click **Uninstall Hush…**. Confirm removal and authorize with your Mac password. You can also choose to delete saved settings.

Pause playback first: audio returns to your device’s hardware volume. Use the built-in uninstaller—moving the app to Trash alone leaves its audio driver installed.

## Build from source

Install Xcode Command Line Tools, then run these commands from the Hush source folder:

```sh
zsh scripts/check.sh
zsh scripts/install.sh
```

This checks the code, builds Hush, and opens the installer. The installer supports both Apple silicon and Intel. Local installers use ad-hoc signatures and are not notarized.

## Compatibility and development

Hush currently supports fixed-volume stereo PCM outputs, including compatible HDMI monitors. Hardware coverage is limited; Bluetooth, reconnect, sleep/wake, and the latest routing fix still need broader installed testing. Multichannel and encoded passthrough audio are not supported.

[Contributing](CONTRIBUTING.md) · [Technical details](docs/ARCHITECTURE.md) · [Release validation](docs/RELEASING.md) · [Security](SECURITY.md)

## License

Hush’s original code and artwork are [MIT licensed](LICENSE). The adapted Proxy Audio Device driver is under the Unlicense, with Apple utility sources retaining their own notices. See [third-party notices](THIRD_PARTY_NOTICES.md).
