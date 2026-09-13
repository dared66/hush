# Audio path

```text
Applications → device-scoped Core Audio tap → stereo gain → same output device
                         │
              excludes Hush’s process
```

The tap captures applications sending sound to the default output’s first stream. `CATapMutedWhenTapped` suppresses their original playback only while the tap is read. A private aggregate combines the physical output with the tap, keeping capture and playback on the output’s clock. The callback copies tap input into output with smoothed attenuation. Hush does not change the system’s default output.

Setup validates stereo Float32 streams and matching sample rates before starting. It rejects physical devices with input streams because the aggregate input layout would differ. Cleanup stops and destroys the callback, aggregate, and tap in that order.

The render callback supports planar and interleaved stereo, clears output before processing, bounds processing to the shortest available buffer, and converts non-finite samples to silence. Gain targets are atomic; the callback alone owns the current gain and ramp. 0–100 maps to squared linear amplitude. No resampling or amplification above unity is performed.

The main thread owns audio setup and UI. A one-second timer checks the default output and refreshes status. Workspace sleep/wake notifications stop and restart processing. Same-device format changes, transient startup failures, and permission changes may require manual reconnect. Callback activity indicates processing activity, not an independent measurement of audible output.

Reference: [Apple’s Core Audio tap overview](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps).
