# Security and privacy

Hush processes system output audio on the local Mac. It does not access the microphone or screen, persist audio samples, make network requests, or ship third-party runtime dependencies. macOS audio-capture permission is required for the Core Audio tap.

Optional `--diagnostics PATH` writes numeric levels, connection errors, and the audio device name to a user-selected file. Do not share that file without reviewing it. Diagnostics are disabled during normal launches.

Only the latest source revision receives fixes. Builds are currently intended for local compilation; a notarized binary distribution is not provided.

Use [GitHub private vulnerability reporting](https://github.com/dared66/hush/security/advisories/new) for security issues. If private reporting is unavailable, open an issue requesting a private contact route without including exploit details, sensitive logs, or captured audio. Do not post secrets in public issues.
