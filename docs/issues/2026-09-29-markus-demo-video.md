# Markus's demo video (2026-09-29), issues and findings

Source: `1001338640.mp4`, a 12:41 screen recording Markus sent with the APK he
had installed (v1.0.1+66 or later, Samsung phone, German UI). Audio was
transcribed with Google STT; Markus mixes German, English and Hungarian, so
items marked *unclear* need confirming with him before work starts.

Status key: `open`, `confirm` (ask Markus first), `done`.

## Issues Markus raised

| # | Where | Issue | Time | Status |
|---|---|---|---|---|
| 1 | Document | Pasting text from the clipboard does not translate automatically; the lower box stays empty until he taps again. "It should translate in the lower area but it is not doing it." | 04:35 | done, verified on device |
| 2 | Document | Tapping the mic opens the edit mode (text editor + keyboard) instead of just recording. "This is also not good." Cause: the Document mic is wired to `EditTextModal`. **Conflicts with his own 2026-07-11 spec** ("tapping mic on the Document page should switch to this exact panel AND start recording", comment in `edit_recording_modal.dart`), so confirm what he wants now. | 05:30 | confirm |
| 3 | Image | Rename the "Image" tab, since it also handles text/PDF documents ("image slash ..."). Exact name not given. | 06:25 | English done ("Text", "Image/Document"); DE/HU wording to confirm with Markus |
| 4 | Image | Switching the target language re-runs the full image analysis ("calculating again") instead of re-translating the text already extracted, so it re-spends WIU. | 07:20 | done (fix built, device test pending): target change re-translates the extracted text; source change still re-reads |
| 5 | Image (explanation mode) | An icon sits too far right: "you need to put it a bit back". Which icon is unclear, probably the `?` ask-question icon in the bottom row. | 08:15 | confirm |
| 6 | History / Favorites / Learning List | All three stay empty ("No history found") after several translations, with Save History on. "It's not showing." | 10:05 | done, verified on device (save, star, Favorites, Save History off, Clear history): nothing but the Document inline check ever saved; Save History switch and Clear history were stubs |
| 7 | Document | The Tutor bulb stays grey for a Hungarian sentence; he expects it to open the Tutor explanation. Root cause: only the active page is mounted, so after a page switch the nav bar bound the bulb to an always-off notifier until something else rebuilt it (`main.dart` `_bulbEnabledListenable`); also each page set the bulb notifier during `build()`. Fixed 2026-10-02, verified on device. | 11:00 | done |
| 8 | General | Asked for ~2 hours to get an overview (what's done, what isn't, what works, how it runs) and to sort out Google Play Store / Apple developer access, which Kayode managed. | 11:55 | open |

## Observed, not mentioned by Markus

| # | Where | Issue | Status |
|---|---|---|---|
| A | All pages | "Your WIU balance is getting low" toast shows constantly. New installs get a 100 WIU welcome grant but the low-balance threshold is 200 (`token_balance.dart`), so every new user sees it from the start. | confirm |
| B | Document | Mixed English/Hungarian dictation produced garbled German. Expected for mixed input, not a bug. | n/a |

## Found and fixed during local testing, 2026-10-02

| Issue | Fix | Status |
|---|---|---|
| Conversation mic did nothing on phones whose built-in recognizer lacks the language (Xiaomi: no Hungarian; English/German not downloaded) | `RecordingModal` now falls back to Google Cloud STT on `error_language_unavailable`/`not_supported`; listeners re-registered per session because `SpeechToText()` is a singleton that only kept the first panel's callbacks | done for EN, HU/DE awaiting voice test |
| Red screen (`_dependents.isEmpty`) after translating from the edit panel, Conversation and Document | `EditTextModal` owns its `TextEditingController`; callers disposed it at `pop()` while still on screen | done, verified |
| Edit-panel mic only worked once per panel | subscribe to `record`'s single-subscription amplitude stream once | done |
| Black flash before the splash in dark mode | `values-night/styles.xml` used `Theme.Black`; now light like the app | done, verified |
| Main screen built twice after splash; 2s fixed splash; first launch blocked up to 10s on welcome-grant network check | single 1s splash timer; welcome grant runs in background | done, verified (~3.0s to ~2.1s) |
| Black icons unreadable on dark backgrounds / photos | Markus's white-outlined icon set (2026-10) swapped in; `b_question.png` used as `b_ask_question.png` to keep the approved shape | done, visual check pending |

## Speech input (mic) findings, 2026-10-02

- **Conversation mic** (`lib/widgets/recording_modal.dart`) uses the phone's
  built-in recognizer (`speech_to_text` 7.0.0). It worked for English on
  Markus's Samsung (02:45).
- **Edit-mode mic** (`lib/widgets/edit_recording_modal.dart`,
  `EditTextModal`) records WAV and sends it to Google Cloud STT with
  `GOOGLE_STT_KEY`. That is what recognized Hungarian in the video (07:10).
- On a Xiaomi 23129RAA4G (Android 15) the built-in recognizer is Google's
  on-device engine (`com.google.android.tts`): no `hu_HU` at all, and
  `en_US` fails with Android error 13 (language unavailable). The app never
  sees the error because `_restartListening()` calls `_speech.stop()` before
  the plugin delivers it, and the plugin drops errors after a user stop. The
  modal then restarts forever and shows nothing.
