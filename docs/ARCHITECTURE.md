# Native volume architecture

Applications → Hush HAL output driver → software volume/mute → physical HDMI output.

The HAL driver exposes real Core Audio volume controls. It proxies audio independently of the background app, matching its clock to the selected output. Core Audio, rather than a custom Hush slider, owns the user-facing volume controls.

The Objective-C routing agent starts silently with `--background`. Opening Hush shows a small settings window with an integrated uninstall action; reopening an existing instance brings that window forward. Closing the window leaves audio routing active. It enumerates live physical outputs, checks native volume support, applies a deterministic hotplug policy, and configures the driver's target. A custom read-only readiness property prevents selecting the virtual output before its destination is prepared. Read-only numeric peak counters support verification without recording audio.

The app stores per-output proxy volume and mute values in its preferences. Graceful agent termination preserves playback through the driver; it does not restore full-volume HDMI unexpectedly. Physical audio continues if the agent crashes, while automatic rerouting waits for the login agent to restart it.

The current driver base contains locks in its upstream processing implementation; this version does not claim lock-free audio processing. Hush patches include distinct driver identifiers, routing-readiness and numeric peak properties, a UTF-8 allocation fix, null configuration handling, self-route rejection, and non-finite sample sanitization.

## Routing and supported formats

Explicit physical-output selection takes priority. Newly connected Bluetooth outputs rank above USB, displays, and built-in speakers; USB ranks above displays and built-in speakers. A newly connected display does not displace higher-priority headphones. On disconnect, routing falls back to an available output. Manually selected unrelated virtual or unsupported outputs are left alone.

Proxying requires stereo, interleaved, 32-bit floating-point PCM. Multichannel and encoded passthrough are unsupported. The driver matches its sample rate to supported hardware rates. The ready-UID property (`huid`) identifies the prepared physical output across process boundaries; numeric Core Audio handles must not be compared across processes.

## Diagnostics

`/Applications/Hush.app/Contents/MacOS/Hush --status` prints output identifiers, routing state, volume/mute, and numeric audio peaks. It does not record audio. Review device identifiers before sharing diagnostics.

After building, `bash "build/Hush.app/Contents/Resources/Uninstaller/uninstall.sh" --dry-run` checks audio restoration without uninstalling anything.

The driver is installed system-wide; its removal affects all users. Preference cleanup applies to the logged-in user. The uninstaller restores playback and sound effects before deleting the app and driver, stopping before deletion if restoration fails. Downloaded installers and source files are retained.
