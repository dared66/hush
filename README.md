# Hush

**A little less loud.**

Hush adds a volume slider to your Mac’s menu bar for stereo HDMI outputs that macOS cannot adjust. Click the speaker icon, set a comfortable level, and get back to what you were listening to.

- System audio volume and mute, including browser playback.
- Remembers your level between launches.
- Optional automatic launch at login.
- Native Objective-C and Core Audio. No third-party libraries or audio driver installation.
- Audio stays on your Mac. No recordings, accounts, analytics, or network requests.

**Status: early beta, built from source.** Confirmed working with a Dell S3221QS over HDMI on Apple Silicon running macOS 26.6.2. Other hardware and older supported macOS versions need testing.

## Requirements

- macOS 14.4 or later.
- Xcode Command Line Tools with a macOS 14.4+ SDK (`xcode-select --install`).
- An output-only device exposing one stereo Float32 stream, such as a compatible HDMI monitor.

Duplex USB interfaces, multichannel outputs, and other sample formats are currently unsupported. DisplayPort devices may work if they expose the required format; they have not been verified. Keyboard volume keys and per-app sliders are not included.

## Build and install

Download or clone this repository, open Terminal in its folder, then run:

```sh
zsh test.sh
zsh scripts/install.sh --login
open "$HOME/Applications/Hush.app"
```

Omit `--login` if you prefer opening Hush manually. Installation uses your personal Applications folder and does not require administrator access. The installer refuses to overwrite an existing app; quit an older Hush and move it to Trash before upgrading.

When macOS asks, allow **System Audio Recording Only**. Hush uses that permission to process live output audio; it does not record audio to a file or access the microphone or screen. If audio does not start after granting permission, choose **Reconnect audio** from Hush’s menu.

For development without installation:

```sh
zsh build.sh
open build/Hush.app
```

Builds are locally ad-hoc signed, not Developer ID signed or notarized for distribution. Rebuilding or changing the bundle identity may require granting audio permission again. Run only one build of Hush at a time.

## Use

Click the speaker icon in the menu bar and drag the slider. Use **Mute / Unmute** to silence playback without losing your saved level. Hush has no Dock icon or main window.

The slider has a perceptual taper: 50% applies one-quarter signal amplitude, giving finer control at quiet levels. **Pause volume control** or **Quit — restore original audio** removes attenuation, so sound returns to the output’s original volume.

Manage automatic login launch:

```sh
zsh scripts/login.sh enable
zsh scripts/login.sh status
zsh scripts/login.sh disable
```

Login launch happens after you sign in, not before the login screen. Quitting Hush keeps it closed until you open it or log in again. To uninstall, disable login launch, quit Hush, and move `~/Applications/Hush.app` to Trash. Settings are stored under `local.hush.Hush`.

## Troubleshooting

- **No sound:** check System Settings → Privacy & Security → Screen & System Audio Recording → System Audio Recording Only. Allow Hush, then reconnect audio.
- **Unsupported output:** select a compatible stereo output in Sound settings. Hush leaves unsupported outputs unprocessed.
- **Audio stops after changing devices or formats:** choose Reconnect audio. Device changes and wake are handled, but reconnect and permission recovery need wider testing.
- **Missing icon:** check whether other menu bar items hide it, then open the app again.
- **Protected playback:** DRM-protected audio has not been verified.

Include the output model, connection type, macOS version, and Hush version when reporting a problem. The read-only device inspector can help:

```sh
build/Hush.app/Contents/MacOS/Hush --inspect
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests and review expectations, [architecture](docs/ARCHITECTURE.md) for the audio path, and the [release checklist](docs/RELEASING.md) for publishing.

GitHub Actions builds the app and runs sanitizer-backed audio tests. CI does not substitute for testing with physical audio hardware. The supported minimum OS is an API target, not a claim that every OS/hardware combination has been tested.

[MIT licensed](LICENSE). See [SECURITY.md](SECURITY.md) for security reporting guidance.
