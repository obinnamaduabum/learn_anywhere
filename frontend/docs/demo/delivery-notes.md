# Learn Anywhere video — delivery notes

The four-minute narrated app walkthrough is `learn-anywhere-4-minute-explainer.mp4`. It contains twelve twenty-second chapters, genuine iPhone 17 screenshots, subtle motion, and burned-in English captions. Separate captions are supplied in `learn-anywhere-captions.srt` (49 sentence cues). `narration.m4a` contains the full voice track; `audio-preview.m4a` contains its first thirty seconds.

## Verified export

- Duration measured with FFprobe: **240.021333 seconds** (4:00).
- Picture: **1920 × 1080**, **24 fps**, H.264, compatible YUV420P.
- Audio: AAC narration. Integrated signal RMS **-17.90 dB**, peak **-1.90 dB**; non-silent with headroom.
- All video and audio fully decoded with FFmpeg, with no reported decode errors.
- Twelve frames sampled from the actual export and visually reviewed, including captions and actual app screens. See `export-contact-sheet.jpg` and the machine-readable `verification.json`.

## Scope and provenance

Screenshots were captured from the current app on 13 October 2026. Empty exterior black margins were cropped; screen content was preserved. The walkthrough did not submit quiz answers or stage learner completion. Quiz submission, answer review, preferences, and source reference behavior are described from the frontend implementation. The reference card and lower profile settings were not captured; their narration is paired with genuine course and profile screens. Reading offline refers to downloaded text packs. Downloading, updating, synchronization, and external source websites need connectivity.

The narration is an original script. It was synthesized locally using the `af_sarah` voice in [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx), with downloaded model files and no text or screenshot upload for synthesis. The video uses no paid services, external stock footage, or background music. The model is listed under Apache 2.0 by its project; its runtime is MIT. FFmpeg and FFprobe performed rendering and verification locally.

`video-script.md` contains the complete narration and chapter timings. `shot-plan.json` contains the editable scene data. `poster.png` is the first chapter's cover image. `storyboard.jpg` shows the planned cards; `export-contact-sheet.jpg` shows frames from the rendered video.
