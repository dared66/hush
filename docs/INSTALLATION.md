# Installation help

[Download Hush.pkg](https://github.com/dared66/hush/releases/latest/download/Hush.pkg) for macOS 14.4 or newer, on Apple silicon or Intel. Open it and follow the installer. Installation requires administrator authorization and briefly restarts audio.

## If macOS blocks the installer

For an “unidentified developer” or “Apple cannot check it” warning:

1. Try opening **Hush.pkg** once, then dismiss the warning.
2. Open **System Settings → Privacy & Security**.
3. Scroll to Security and click **Open Anyway** for Hush.
4. Confirm **Open**, then continue installation.

Only approve a download you trust from [this repository’s Releases](https://github.com/dared66/hush/releases). This approves the specific download; you do not need to disable Gatekeeper globally or run Terminal commands. If macOS reports malware or a damaged file, stop rather than treating it as the same warning. A managed work or school Mac may not allow an override. See [Apple’s instructions](https://support.apple.com/en-us/102445).

## What works without notarization?

- **Download and install:** the ready-made installer is available, but macOS may require the approval above.
- **Volume, mute, and startup:** notarization is not a feature unlock. Once the app and driver are allowed to run, its absence does not itself disable these features or the built-in uninstaller.
- **Updates:** a new download may require approval again. We cannot promise a single approval forever.
- **Installation reliability:** we have not yet verified the GitHub-downloaded package’s complete installation, driver loading, and uninstall on a clean Mac. Automated checks do not establish that every Mac will accept it.

## Why isn’t Hush notarized?

Hush does not currently fund a paid Apple Developer Program membership. Apple lists membership at **US$99 per year**, with local pricing where available and fee waivers for some eligible organizations. This is a developer expense, not a fee Hush users need to pay. [Apple membership details](https://developer.apple.com/programs/enroll/).

The app and driver have **ad-hoc signatures**, not an Apple-issued Developer ID signature; the installer package is not Developer ID signed either. Ad-hoc signing does not verify the publisher’s identity to Apple. Notarization adds Apple’s automated malware check; it is not a guarantee of audio reliability.

Developer ID signing and notarization would remove the normal unidentified-developer workaround. Administrator authorization would still be needed to install Hush’s system-wide audio driver. For now, expect the extra approval step and the experimental limitations above.


## Build from source

Install Xcode Command Line Tools, then run these commands from the Hush source folder:

```sh
zsh scripts/check.sh
zsh scripts/install.sh
```

This checks the code, builds Hush, and opens the installer. The installer supports both Apple silicon and Intel. Local installers use ad-hoc signatures and are not notarized.


## Compatibility

Hush currently supports fixed-volume stereo PCM outputs, including compatible HDMI monitors. Multichannel and encoded passthrough audio are not supported. Hardware coverage is limited; Bluetooth, reconnect, sleep/wake, and the latest routing change still need broader installed testing. See [release validation](RELEASING.md).

At 100%, Hush sends audio without attenuation. The monitor’s own volume setting still affects loudness.

New installers are published in [Releases](https://github.com/dared66/hush/releases) after each push to `main` passes automated checks.
