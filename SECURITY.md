# Security and privacy

Hush handles live audio locally. It contains no recording, analytics, or network functionality. Diagnostics expose output-device identifiers, routing state, volume/mute, and numeric audio peaks. Review identifiers before sharing output.

Installation and removal require administrator authorization because the HAL driver is system-wide. The routing agent runs as the logged-in user. The uninstaller stages its helpers in a private temporary directory before removing the app. It writes a restricted diagnostic log to a uniquely named file under `/private/tmp/hush-uninstall-log.*`; that log may include device names.

Downloads are not Developer ID signed or notarized. See the [installation and signing FAQ](README.md#if-macos-blocks-the-installer) for approval steps and limitations.

This is experimental software. The uninstaller’s authorization API is deprecated, and end-to-end privileged removal and broader hardware coverage remain release requirements. See [release validation](docs/RELEASING.md).

No private security-reporting channel is configured in this source distribution. A hosting maintainer should enable private vulnerability reporting before publishing. Avoid posting credentials, personal identifiers, recordings, or exploit details in public issues.
