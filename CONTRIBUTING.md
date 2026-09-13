# Contributing to Hush

Small, focused improvements are welcome. For larger features, open an issue to discuss the intended behavior first.

## Local checks

```sh
zsh build.sh
zsh test.sh
zsh scripts/check.sh
```

Keep the render callback free of locks, memory allocation, Objective-C messaging, file access, and logging. Add regression tests when changing sample processing or buffer handling. Tests run without audio permission or physical hardware and use AddressSanitizer and UndefinedBehaviorSanitizer.

Explain the user-visible change and what you tested in your pull request. Include hardware and macOS versions for audio changes. Do not claim device support solely because the app compiled.

## Manual audio checks

At a comfortable hardware volume, verify playback, slider movement, mute/unmute, pause/resume, and quit restoring the original audio. Check permission denial and later grant, device disconnection, output changes, sleep/wake, and login launch. Verify that failed setup leaves original audio available. Permission prompts must be handled by the tester; do not automate changes to macOS privacy databases.

## Project structure

- `src/main.m`: device setup, process tap lifecycle, menu bar UI.
- `src/AudioRender.m`: allocation-free audio callback.
- `src/Gain.h`: gain smoothing and sample sanitization.
- `src/tests.m`: synthetic audio regression tests.
- `scripts/`: local installation, login management, and source packaging.

Use a current macOS SDK and preserve the 14.4 deployment target unless a change explicitly updates requirements. Contributions are provided under the repository’s MIT license. Be respectful and describe problems with code or behavior rather than people.
