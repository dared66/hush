<p align="center"><img src="assets/Hush.png" width="112" alt="Hush icon"></p>
<h1 align="center">Hush</h1>
<p align="center">Your Mac’s volume controls, for your monitor.</p>

Monitor volume grayed out on your Mac? Hush lets you adjust it with the volume keys and the macOS Sound slider. No extra menu-bar slider.

<p align="center"><img src="assets/screenshots/macos-volume-control.png" width="480" alt="macOS Sound panel with DELL S3221QS (Hush) selected and the system volume slider available."></p>

## Install

Requires **macOS 14.4 or newer**.

1. Open the **Hush `.pkg` installer**.
2. Follow the prompts and enter your Mac administrator password when asked.
3. Hush starts automatically, including after you restart your Mac.

Pause playback or calls before installing—audio restarts briefly.

**This is an experimental source release.** There is no notarized public download yet. If you don’t already have an installer, follow [Build from source](#build-from-source) below.

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

This checks the code, builds Hush, and opens the installer. Builds target your Mac’s architecture. Local installers use ad-hoc signatures and are not notarized.

## Compatibility and development

Hush currently supports fixed-volume stereo PCM outputs, including compatible HDMI monitors. Hardware coverage is limited; Bluetooth, reconnect, sleep/wake, and the latest routing fix still need broader installed testing. Multichannel and encoded passthrough audio are not supported.

[Contributing](CONTRIBUTING.md) · [Technical details](docs/ARCHITECTURE.md) · [Release validation](docs/RELEASING.md) · [Security](SECURITY.md)

## License

Hush’s original code and artwork are [MIT licensed](LICENSE). The adapted Proxy Audio Device driver is under the Unlicense, with Apple utility sources retaining their own notices. See [third-party notices](THIRD_PARTY_NOTICES.md).
