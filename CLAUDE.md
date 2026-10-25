# Forditva — Project Notes for Claude

Handoff notes so any Claude (or developer) can pick up this project. Kept
current as of **2026-08-05, version 1.0.1+68**. Update the "Current status"
and "Open / blocked" sections as work lands.

## What this is

Forditva is a **Flutter** speech + text + image translation app. Core language
pair is **Hungarian ⇄ German**; a third language is user-selectable
(EN/NL/FR/IT/RU/ES). It is branded for the **wir-in-ungarn.hu** community. The
client is **Markus Messemer** (communicates via Telegram; the user/developer
here is **Kayode**, "Jordanz"). Markus's web developer is **Alex** (Aliaksandr; headless WordPress + Next.js;
replaced Shahin Alam, who built the prepaid code list). **Andy** is Markus's
Linux admin and decides what runs on the servers (2026-10-12).

Stack: Flutter/Dart, **Gemini** for translation + image OCR (raw REST,
`gemini-flash-latest`), Google Cloud **STT** + **TTS**, `drift`/sqlite for
history, `flutter_localizations` (EN/DE/HU ARB files in `lib/l10n/`). Secrets
live in a bundled `.env` (Flutter asset): `GEMINI_API_KEY`, `GOOGLE_STT_KEY`,
`OPENAI_API_KEY`, `LINGVANEX_API_KEY`, `PREPAID_API_BASE_URL`,
`PREPAID_API_KEY`.

## Repo & environment

- Repo root: `D:\projects\forditva\forditva` (double-nested; the outer
  `D:\projects\forditva` just wraps it). Git branch: **main**.
- Flutter SDK: `D:\tools\flutter` (not on PATH by default; call the full path).
- JDK 17: `C:\Program Files\Java\jdk-17` (and a Temurin 17 under
  `C:\Program Files\Eclipse Adoptium\`).
- The project lives on the **D: drive**. It has been unmounted at times (e.g.
  after a laptop repair). If `D:\` is missing, the project is unreachable; the
  bundled `.env` can be extracted from a built APK
  (`assets/flutter_assets/.env`) if you need a key while D: is down.

## Build & deploy — READ before building

**Local Android builds fail on this Windows machine** with
`java.io.IOException: Unable to establish loopback connection` (root cause:
`sun.nio.ch.PipeImpl` opens an AF_UNIX socket whose `connect` fails here). The
fix is the JVM property **`jdk.net.unixdomain.tmpdir`** (NOT `java.io.tmpdir`):

```
JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:\jtmp"
GRADLE_OPTS="-Djdk.net.unixdomain.tmpdir=C:\jtmp"
```

set on the build command (create `C:\jtmp` first). Setting it only in
`org.gradle.jvmargs` does NOT work (Gradle filters custom -D from the daemon).
Confirmed working 2026-07-23. Reboot / JDK upgrade / `java.io.tmpdir` overrides
do nothing.

**Because of that, builds run on GitHub Actions** (workflows in
`.github/workflows/`):

- `android-apk.yml` — auto on every push to main. Debug-signed **APK** for
  **sideload testing** (this is what Markus installs). Download the artifact:
  `gh run download <run-id> -n forditva-apk`.
- `android-aab.yml` — **manual** (`workflow_dispatch`). Upload-key-signed
  **.aab** for the **Play Store**. Artifact name `forditva-aab`.
- `ios-testflight.yml` — auto on push. Builds the IPA and uploads to
  **TestFlight** (App Store Connect API key auth).

`android/gradle.properties` pins the JVM to 1536m for the RAM-constrained local
machine; the CI workflows bump it to 4g (Jetifier OOMs at 1536m on the runner).

**Always verify a downloaded APK's signature before sending it to Markus:**
`apksigner verify --print-certs <apk>` and confirm the SHA-256 below.

## Signing keys

- **2026-10-02: new sideload key.** Kayode (and his key below) became
  unreachable, so tester APKs from v1.0.1+70 on are signed with
  `.deploy/forditva-sideload.jks`, SHA-256
  `32:B6:75:A1:F3:A7:4E:7E:AC:4C:82:61:05:BF:94:1F:87:C3:ED:C8:28:40:96:2E:4F:CF:AD:3D:F3:65:74:F9`.
  Build with `FORDITVA_DEBUG_KEYSTORE="$PWD/.deploy/forditva-sideload.jks"`;
  details and backup notes in `.deploy/SIDELOAD_SIGNING.md`. Testers had to
  uninstall the old build once (losing local WIU balance). The notes below
  describe the old setup.
- **Debug/sideload key** (all APKs Markus installs): SHA-256
  `037e7f9488a7920ad7961494f89c697207f1b71a72ae9b12e8f76a7e2530401c`. The
  release build type signs with the *debug* key so testers can install updates
  over the top. The real `~/.android/debug.keystore` is stored as GitHub secret
  `ANDROID_DEBUG_KEYSTORE` (base64); `build.gradle.kts` reads
  `FORDITVA_DEBUG_KEYSTORE` to use it on CI. The APK workflow **fails** if the
  built APK's signer != repo variable `ANDROID_SIGNING_SHA256`. Do not let a
  runner-generated key ship: Play Protect blocks it and testers can't update.
- **Play upload key** (the .aab only): **reset 2026-10-21** (Kayode's July
  key `1F:51:...:8F:75` was lost), alias `upload`, SHA-256
  `F5:2C:45:91:9F:D7:C1:BC:1A:2B:C4:A8:7C:83:86:09:F8:B7:B1:36:6E:4D:26:90:9B:98:D0:AE:34:E6:7C:CE`,
  valid from 2026-10-23 20:03. Lives in **`.deploy/`**
  (gitignored: `upload-keystore.jks`, `upload-keystore-password.txt`,
  `PLAY_SIGNING.md`) AND as GitHub secrets `ANDROID_UPLOAD_KEYSTORE`(base64) /
  `_KEYSTORE_PASSWORD` / `_KEY_ALIAS` / `_KEY_PASSWORD`. `build.gradle.kts`
  signs release with it only when `FORDITVA_UPLOAD_KEYSTORE` is set (the AAB
  job); otherwise release still uses the debug key. **`.deploy/` is not in git —
  back it up off-machine. Losing the upload key needs a Play support reset.**
- **Play app signing key** (Google's; Play re-signs the AAB with it, and
  Firebase App Check needs it): SHA-256 `03:FD:44:FE:...:D5:42:E9`.
- iOS signing is fully automated in `ios-testflight.yml` via the App Store
  Connect API key (GitHub secrets `APP_STORE_CONNECT_*`, `APPLE_TEAM_ID`,
  `IOS_BUNDLE_ID`). iOS bundle id: `hu.wirinungarn.forditva3`.

## App identifiers

- **Android applicationId: `hu.wirinungarn.forditva`** (changed 2026-07-23 from
  the default `com.example.forditva`, which Play rejects). The internal
  `namespace`/MainActivity package is still `com.example.forditva` (code-only,
  fine). Because the applicationId changed, the +57 build installs as a **fresh
  app** — testers uninstall the old `com.example` build once, then install the
  new one; updates are normal after that.
- iOS bundle id: `hu.wirinungarn.forditva3`.

## Current status (2026-08-08, v1.0.1+69)

Latest verified sideload APK for Markus:
`Downloads\forditva-2026-08-08-de-hu-strings.apk` (v1.0.1+69, package
`hu.wirinungarn.forditva`, debug-key signed, signer SHA-256 verified against
`037e7f9488a7920ad7961494f89c697207f1b71a72ae9b12e8f76a7e2530401c`). iOS +69
build path is the same commit and also succeeded on CI. +69 = Markus's final
German/Hungarian for the two remaining document-conversion strings
(progress states + conversion-failure dialog), replacing the English
fallback. **The document-conversion feature itself still won't work yet**
(Firebase project doesn't exist), see the dedicated section above —
everything else in the app is unaffected and fully functional. One icon
still needed from Markus: a generic document icon (no "PDF" text on it) to
replace the PDF-branded one now shared across all supported file types —
asked, not yet sent.

Note on +68's two commits: `da4c175` added the whole document-conversion
feature; CI then caught a real iOS-only build break (firebase_app_check
needs a higher deployment target than the project's default 12.0), fixed in
`cbd6554` by raising it to 15.0. Both commits are version 1.0.1+68. +69
(this APK) builds on `cbd6554`.

Version history since +58: +59 = icon repositioning + Tutor header
localization (commit `ddb6b5b`); +60 = upload-area text/icons + final
ask-question copy; +61 = text color/size fix after Markus tested +60 on
TestFlight; +62 = ask-question icon made visible in translate mode (it had
been interpret-mode-only, so most users never saw it, but this turned out to
be wrong per +64 below); +63 = explanation-mode icon now distinct from
translate icon, stale result on new upload fixed, per-mode result caching so
toggling translate/explain doesn't re-spend WIU, loaded-PDF toolbar icon + PDF
page-picker German wording (commit `87684cb`); +64 = **reverted +62** — Markus
explicitly wants the ask-question icon shown only in explanation mode
("This question icon must only be shown, when explanation mode is active"),
swapped in his refined question-mark icon asset (sent 2026-07-24, never wired
up until now), added more spacing between the upload-area icons and text;
+65 = Markus tested +64 and confirmed the per-mode icon fix was right, but
flagged a leftover grey circular highlight behind the mode button ("nearly
correct. But NO grey background behind explain button") — dropped it, the
distinct glyph per mode is enough on its own; +66 = ask-question answer was
generated in the app's UI language instead of the selected target language
(_leftLang) — same bug class as the old language-mismatch issues elsewhere in
this file, fixed the same way; also grew the question text field to 3 visible
lines (was 1) so it signals longer questions are welcome; +67 = shrank the
Image page result text (was oversized: flat 24px translate-mode text, up to
50px interpret-mode HTML) and wired up real pinch-to-zoom via raw pointer
tracking, since nothing previously moved `_zoomLevel` off its 1.0 default
(commit `0ccf3bc`); +68 = added the whole document-conversion feature, see
the dedicated section above (commits `da4c175` + `cbd6554`); +69 = Markus's
final German/Hungarian for the two remaining document-conversion strings,
replacing the English fallback.

Note: the iOS TestFlight upload for +62 failed once on a transient Apple
Content Delivery error (500 then 409 "resource currently being updated") —
the IPA itself built fine, a plain re-run of the failed job succeeded. Not a
code issue; if it recurs, just re-run the job.

**Standing rule (Markus, 2026-07-24): never author final DE/HU translations
myself.** Draft proposed copy and send it to Kayode to relay to Markus for
correction before integrating — do not ship self-written German/Hungarian
text directly. EN copy is fine to ship directly; text Markus has already
supplied verbatim is pre-approved.

## This session's work

All shipped to main and built on CI:

1. **PDF page picker (Image page).** `lib/widgets/pdf_page_selector.dart`
   (`PdfPageSelectorDialog`). A **modal** over the dimmed Image page that renders
   each PDF page to a thumbnail with **`pdfx`** (iOS PDFKit / Android
   PdfRenderer, rendered serially — Android can't render pages in parallel), and
   the user ticks pages with a corner checkbox. Assets:
   `assets/png24/black/b_checkbox_checked|empty.png`, `b_arrow_left|right.png`.
   Selected pages collapse to a spec ("1-3,5") fed to the existing Gemini prompt.
   Replaced the old "type a page number" dialog.
2. **"No matching text found" message.** When Gemini returns an empty result
   (found no text in the selected source language) the app now says to check the
   source language, instead of the misleading "image not clear". Note: the test
   PDF Markus reported (`Hungarian-Contemporary-001-009.pdf`) is **English text
   about Hungarian art**, so selecting Hungarian correctly finds nothing — not a
   bug.
3. **+30% translation fee margin.** `lib/services/gemini_cost.dart` — a
   `feeMargin = 1.30` multiplier on the real per-token cost (Markus: stay covered
   on fees even if the estimate runs low). Applies to text + image translation
   (both bill through `geminiWiuCost`); TTS bills separately and did NOT get it.
   Locked in by `test/gemini_cost_test.dart`.
4. **Play Store prep.** New package name + upload signing + `android-aab.yml`
   (see above). AAB build validated on CI.
5. **"Ask about this document" button (Image page).** `lib/widgets/document_question_dialog.dart`
   (`DocumentQuestionDialog`) — a modal with a text field where the user types
   a free-text question about the loaded image/PDF; answered by Gemini from
   the document's own content (`GeminiImageService.askAboutDocument`, reusing
   the same inline_data call as translation). Answered in the app's UI
   language, same convention as the Tutor explanation. New "?" icon
   (`assets/png24/black/b_ask_question.png`, supplied by Markus) added to the
   Image page's bottom icon row, next to the speaker. Costs WIU like image
   translation (same `geminiWiuCost`, including the +30% fee margin).
6. **Ask-question icon repositioning + Tutor header localization (2026-07-24,
   commit `ddb6b5b`).** Markus's exact spec (voice note, 2026-07-23): the icon
   row runs Paste, Share, Zoom, then the mode-switch button; the slot right
   after it holds the ask-question icon (it had been sitting at the very end,
   after the speaker), with the speaker last. Also fixed hardcoded English
   "Key Vocabulary"/"Translation"/"Grammar Explanation" Tutor headers in
   `textpage.dart`, `learning_list.dart`, `document_translation_page.dart` —
   switched to the existing (already-localized) `AppLocalizations` strings,
   already used correctly in `widgets/tutor_dialog.dart`. Conversation-page
   Tutor modal widened (insetPadding 40→16, maxHeight 0.85→0.9), reported as
   too small.
7. **Upload-area text + icons (Image page empty state), 2026-07-24.** Replaced
   the old single-sentence-with-inline-link empty state with Markus's exact
   spec (`upload_area_i18n.json`): three lines — "Take a photo" / "or" /
   "Upload an image or PDF" — first and third lines tappable, matching their
   icon. Camera icon swapped from a generic Material icon to Markus's
   `b_photo.png`; folder-open icon swapped to his new `assets/png24/black/b_pdf.png`.
   Also replaced the "ask about this document" dialog's placeholder strings
   with Markus's exact final DE/EN/HU copy (`document_qa_i18n.json`) — the
   dialog title, hint, button, and error text from item 5 above were English
   placeholders until now.
8. **Upload-area text styling fix, 2026-07-24.** Markus tested +60 on
   TestFlight and found the red 20px text hard to read against the white
   background. Changed to black, 26px (30% larger).

## Document-conversion feature (Office/text → PDF), 2026-08-05, v1.0.1+68

Gemini's `inline_data` only accepts images and PDF, not DOC/DOCX/XLS/XLSX/
ODT/ODS/TXT. Markus approved converting those formats to PDF via a
self-hosted LibreOffice service first, then feeding the result through the
**existing** PDF path unchanged (page picker, then `_callGemini`). Full
design discussion and Markus's decisions are in the 2026-08 Telegram export;
the short version:

- **Client side (this repo, done):** `lib/image_page.dart`'s file picker now
  accepts doc/docx/xls/xlsx/odt/ods. Non-image/PDF files go through
  `lib/services/document_conversion_service.dart` (`DocumentConversionService.
  convertToPdf`), which POSTs to
  `https://convert.wir-in-ungarn.hu/convert/to-pdf` (constant in the code;
  `CONVERSION_API_BASE_URL` in `.env` overrides it) with a Firebase App Check
  token, then the result flows into the same `PdfPageSelectorDialog` +
  `_processImage` path a directly-uploaded PDF uses. Conversion failure shows
  a dedicated dialog (`conversionFailedTitle`/`Body`), and `_statusText`
  shows "Converting document..." then "Analyzing and translating..." during
  processing (was silent before, just the loader gif).
- **Auth (Markus, 2026-08): explicitly no bundled static API key** ("we
  should not use a bundled static API key... I prefer the properly secure
  solution over the short-lived-token fallback"). Uses Firebase App Check —
  Play Integrity provider on Android, App Attest on iOS — via `main.dart`'s
  `_initFirebaseAppCheck()`. This proves a request comes from a genuine,
  unmodified app install with nothing embedded to extract.
- **Backend (`conversion-service/`, deployed by Andy 2026-10-23):** rewritten
  2026-10-16 from Markus's FastAPI draft (Python + LibreOffice headless in
  Docker), replacing Kayode's Node version. `POST /convert/to-pdf`. Andy's
  proxy adds a rate limit (3 quick requests, then 429) and a 16 MiB body cap.
  Firebase App Check token checked against Google's public JWKS (no
  service account); optional test key only from 127.0.0.1 inside the
  container. Limits (Markus, 2026-10-14): 15 MB upload, 30 MB PDF, 2
  parallel, 90 s. Andy hosts it at `convert.wir-in-ungarn.hu`. See
  `conversion-service/README.md`.
- **Cost:** no separate surcharge — converted files bill through the exact
  same `geminiWiuCost` (+30% margin) as any other PDF, by construction (they
  become a real PDF before Gemini ever sees them).
- **WIU balance note (Markus, 2026-08):** explicitly flagged as a *separate*
  issue to revisit later — the local-only (not server-verified) WIU balance
  is unrelated to this endpoint's auth, App Check protects the conversion
  server from abuse, it does not make WIU spend server-authoritative.

**Status (2026-10-23):** the Firebase project (`forditva-151`), Andy's
deployment and Markus's DE/HU strings are all in place, so the feature is
live from v1.0.1+74. Tested from the Mac with an App Check debug token:
DOCX, XLSX, ODT, ODS and DOC all convert.

## Open / blocked tasks (from the 17-22 Jul Telegram export)

- **Issue lists live in `docs/issues/`**, one file per feedback round (latest:
  `2026-09-29-markus-demo-video.md`). Keep details there, not here.

- **Forditva → Play Store: BLOCKED on Markus.** He must open the Play Console
  ($25, Personal account, identity verification ~1-2 days), add Kayode's Google
  email as Admin, and send 12 tester emails for the mandatory 14-day closed
  test. Then: build the store listing (German short + long description — Kayode
  drafts), upload the .aab (`android-aab.yml` artifact), content rating +
  data-safety forms, start the closed test. Privacy policy already exists:
  wir-in-ungarn.hu/datenschutz-forditva.
- **wir-in-ungarn scheduling + video-call confirmation email** (regio.is,
  Shahin's WordPress side): finish the scheduler and make the confirmation email
  actually send to the user when Markus schedules a video meeting.
- **URL Shortener** — new project, shortens links to **wiu.hu** (short domain
  for wir-in-ungarn.hu). Python backend (PostgreSQL) + Next.js frontend;
  framework TBD (FastAPI vs Flask). Markus is generating a base with AI;
  review before modifying. Markus, 2026-07-24: **wants Forditva finished
  first** ("I need a working forditva before you can round up it") — don't
  start this until Forditva is in a state Markus considers done.
- **Audio player** — new project for wir-in-ungarn.hu, mentioned 2026-07-24.
  No spec yet beyond "the audio player is also for wir-in-ungarn"; ask Markus
  what it's for before starting.
- **"tudva"** — new project. A discussion platform for the wir-in-ungarn
  community: users post/discuss in their own language (DE/HU/EN) and each sees
  every message translated into their own language in parallel columns; tasks
  get generated out of the discussions. Markus will spec it.
- **TTS fee margin** — the +30% was applied to translation/image only. Ask
  Markus if he wants it on TTS too (one-line change in `gemini_tts_service.dart`).

## Client & workflow notes

- Markus relays feedback via Telegram text, transcribed **voice notes** (German,
  sometimes English), and **screenshots**. Voice notes are transcribed with
  Google STT using `GOOGLE_STT_KEY`. Telegram exports land in
  `C:\Users\KAYODE SOLIU\Downloads\Telegram Desktop\`.
- **Do not overpromise.** Markus has been burned by vague "soon" timelines.
  Give honest, specific status.
- Asset rule (emphatic): resizing his supplied assets is fine, but **never change
  their shape** (flags stay square-with-rounded-corners, never round).
- Established loop per change: find root cause in code (don't guess) → fix
  surgically → `flutter analyze` (clean) → bump `pubspec.yaml` build number →
  push (CI builds) → verify APK signature → rename into Downloads → report both
  Android + iOS results.

## Writing style

Prose the client sees (messages, commit messages, docs): no em dashes, active
voice, specific, no filler. See the user's global stop-slop rules.
