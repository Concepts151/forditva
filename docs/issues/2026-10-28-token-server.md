# Token Server switch, 2026-10-28 (1.0.4, build 78)

Alex (27 Oct): the Token Server is live at
`https://forditva-api.wir-in-ungarn.hu`. Switch the app from the WordPress
prepaid codes to it, with his `forditva_token_client.dart` and `docs/API.md`
sections 3-7. Markus's new gift codes failed in 1.0.3 (77) with "Dieser Code
ist ungültig...", because the app still asked WordPress, and the server had
never seen a request from the app.

Alex sent (28 Oct): `forditva_token_client.dart`, `dependencies.txt`,
`API.md`. Copies in `~/Downloads`. API.md sections 1-8 are the same as the
16 Oct copy. The new §9 (read-aloud voices) and §10 (Gemini on "eu") already
match the app.

| # | Item | Status |
|---|---|---|
| 1 | Wallet on the Token Server instead of WordPress codes and the local welcome grant | built, unit-tested; phone test open |
| 2 | First launch: start with 200 WIU or enter a recovery code | built; phone test open |
| 3 | Recovery code shown once; restore and new code in Settings | built; phone test open |
| 4 | DE/HU texts for the new dialogs | replaced by Markus's final texts (29 Oct), in build 79 |
| 5 | Gift code for the phone test | ask Alex for a test code |
| 6 | Conversation: changing the dark side's language also blanked and refilled the white side (Markus's video, 29 Oct) | fixed, in 1.0.4; not seen on the phone yet |
| 7 | Tutor: waits over 30 s need more feedback than a spinner (Markus's voice note, 29 Oct) | Markus picked A with changes (29 Oct); built in build 79 |
| 8 | New terms: credits, top-up code, backup code; no "WIU" in the UI (Markus, `text modifications.md`, 29 Oct) | built in build 79 |
| 9 | Wallet dialogs in Roboto Condensed (Markus: "Wiederherstellungscod/e" broke mid-word) | built in build 79 |
| 10 | Tutor: "Answer now" did nothing, then "service unavailable" (Markus's voice note 13.52, 29 Oct) | open; Markus: texts first, then look again |
| 11 | File page: a bigger PDF fails after about 10 s with "Der Dienst ist vorübergehend nicht verfügbar"; Markus wants progress feedback instead (screenshot 14.54.44, 29 Oct) | cause confirmed: his PDF is 15.3 MB (2 pages), about 20.4 MB once encoded, over Gemini's 20 MB per request; the app sent the whole file even for page 1. Markus: block too big files. Build 79: files over 14 MB get a "File too large" dialog before anything is sent (checked right after picking a PDF and before every request). Page-by-page progress not built |
| 12 | File page: the PDF icon opens images and files too, "makes no sense" (Markus's voice note 17.38, 29 Oct) | build 79: both places use his plain document icon `b_document.png`; tell him he can send a folder icon instead |
| 13 | Photo cutter: "Please connect the shape back to the start!" in English, and an outline 1-2 px off the start was thrown away (screenshot 17.40.41, voice note 17.41.45, 29 Oct) | build 79: lifting the finger closes the shape with a straight line to the start; the message is gone. Also replaced the last hardcoded English error ("TTS failed: <path>") with the localized read-aloud message |
| 14 | File page, explain mode: an empty line between every paragraph and list, the bullet list indented too far, extra space at the top (Markus's video `recording-2026-10-29-14-17-45.mp4`, edited in Photoshop) | build 79: flutter_html defaults replaced in `_resultBody`: no body margin, 0.5 em after paragraphs and lists, 0.3 em between list items, list indent 40 px → 1.2 em, headings 0.3 em. Not seen on a phone yet (needs a real AI answer) |
| 15 | Page picker says "pdf-importer" after a Word/Excel upload; users won't understand (Markus's voice note 18.58, 29 Oct) | built, not committed: for a converted file the title is "Dokument importieren" plus "Wir haben deine DOCX-Datei in ein PDF umgewandelt, damit fordítva sie lesen kann." (DE/HU drafts). Real PDFs keep "pdf-importer" |
| 16 | Loaded-file icon: show DOC/XLS/... instead of PDF (voice note 19.00, 29 Oct) | waiting for Markus's icons. Sent him the current ones (`~/Downloads/Forditva-icons-for-Markus/`): the big icon is Material `picture_as_pdf`, 72 dp, #CD2A3E, 512 px with 43 px margin. The app needs to keep the original type for this (`_convertedFrom` now does) | **Update:** Markus sent pdf/doc/xls/txt (512 px, transparent, #CD2A3E). In `assets/png24/red/r_*.png`; the loaded-file panel picks by type (DOC/DOCX/ODT → doc, XLS/XLSX/ODS → xls, TXT → txt, else pdf) and shows the original file name ("Brief.docx") instead of the converted PDF's. Not committed |
| 17 | (Alex, 2 Nov: enforcement is on again and build 81 calls are all VALID and 200.) Every AI call failed with "Firebase AI Logic genai config not found" on 79 (29 Oct evening) | Alex: since he enforced App Check for AI Logic, the standard 1-hour token counted as reused (metric CONSUMED, app id UNKNOWN), answer 400. He set enforcement back to monitoring; 79 translated again at 22:25. Build 80: `useLimitedUseAppCheckTokens: true` in `gemini_firebase.dart` (the only place a model is made). Must be on Play before 2 Nov, when Google enforces App Check for AI Logic. Tested from Play, not a debug build (the user's call). iOS later: flutterfire issue 18718 (limited-use token is a standard one on iOS) |
| 18 | Build 80 phone test (Play, 29 Oct, over adb) | translation, Word → PDF conversion + translation, explain spacing, icons, Tutor bar and "takes longer" note all work. Not tested: tapping "Shorter answer", voice input. Each AI call now waits 2-5 s for its own Play Integrity token; Play's limit is 10,000 per day (told Alex) |
| 19 | File page: no loader during conversion; English upload hint missed Word/Excel; "1 single pages. Which from them..." | built for 81: loader + "Converting document..." during conversion; EN hint lists PDF, Word, Excel, OpenDocument, text; page count with a proper singular in EN/DE/HU (DE/HU singular drafted) |
| 20 | Tutor from the File page in explain mode got the German explanation; Decoding then failed after about 90 s with "service unavailable" | cause reproduced: on German text the Decoding prompt answers `[]` (57 s), on the Hungarian original a correct decoding (12 s); the app counted `[]` as invalid JSON and retried. Built for 81: the File page gives the Tutor the Hungarian of the same document's translation (no translation → bulb off); an empty answer stops at once with "I couldn't find a Hungarian sentence in this text..." (DE/HU drafted), no retry button |
| 21 | Text page: Tutor after English → Hungarian explained the English input; Decoding showed English three times (user test on 80, 29 Oct) | cause: `openTutor()` in `document_translation_page.dart` read the language pair backwards (`_rightLang` is the source there); the bulb check above it was already right. Fixed for 81. Conversation page checked: its mapping is right |
| 22 | Default purple spinners and text cursor (user, 29 Oct) | built for 81: the app theme sets the spinner, cursor, selection and handle colors to navGreen. Material 3 ignored `primarySwatch: Colors.green` |
| 23 | Tutor waiting text (Markus, 2 Nov, screenshots 17.22.28 / 17.23.45, voice notes 17.24-17.25): "looks fine now", but say it can take longer; the sentence-split spinner shows no text | built for 82, not committed: his text in EN/DE/HU word for word, two lines (the break after the first sentence is a real line break). The split spinner now says "Einen Moment bitte, ich bereite Deine Antwort vor." (his first line only; he suggested "maybe not with a bar, but with some text"). His new text names "about 30 seconds", which his 29 Oct rule ("never show estimated seconds") ruled out for the Shorter answer button; this is his own wording, so used as sent. The bar and the "takes longer" note still use the phone's own median (about 21-25 s on 80), so the note appears before 30 s |
| 24 | "Falsche Sprache" dialog: the label "Deutsch verwenden" is cut off on its button (Markus, 2 Nov, screenshot 17.29.23, voice notes 17.30; the message itself is correct) | built for 82, not committed: the buttons sit below each other, full width; "Deutsch verwenden" (green) first, "Abbrechen" (red) below. The dialog is shared by the Text, File and document pages, so all three get it |
| 25 | File page: after a trip to the Tutor and back, the page selection (4-5) was gone and the next switch to explain mode read the whole document again (Markus, 2 Nov, voice notes 17.33.17/21, with `Dinkel-Buchweizen-Rührmasse - tragfähig, mit Schmand.xlsx`) | cause: main.dart builds only the current page, so the File page lost its state when the Tutor opened; only the last image and result were on disk, not the pages, the two results or the mode. Built for 82, not committed: `_FileSession` keeps file, pages, original type, both results, mode and languages in memory while another page is open (and restores them if the third language is unchanged). Lost on app restart, as before. A result still being generated when the user leaves is lost. Markus's compliment (17.33.55: \"a big compliment... a really good base\") |
| 26 | Photo crop: the translation includes text outside the outline (Markus's video 17.34.29: the engraved name labels above his selection) | cause reproduced: the cut-out mask was a 3-channel image, so its alpha read 255 everywhere and nothing outside the outline was removed; the AI got the whole bounding box. Built for 82, not committed: `cutOutPolygon()` in `cropper.dart` (4-channel mask, outside painted white, works on the small crop only); photos are also turned upright (EXIF) before the outline is applied. New tests. Markus also asked for feedback while the translation runs after tapping OK (voice note, not done: the page shows the loader only after the cropper closes) |
| 27 | Cropper text and buttons (screenshot 17.37.11, his texts) | built for 82: "Was möchtest du übersetzen?" in Roboto Condensed Bold 18, the second line Medium 16; ✗ and ✓ 64 → 50; texts EN/DE/HU as sent (new key `cropInstructionBody`) |
| 28 | New camera photo kept the previous image's results: switching explain → translate showed the old text (Markus's voice note 17.38.06, screenshot 17.38.00) | cause: `_takePhoto` did not clear the result caches, the gallery path did. Built for 82: the camera uses the same path (`_loadImageWithCropper`) |
| 29 | Tutor from the File page showed German sentences in the picker (screenshot 17.39.20, voice note 17.39.55), on build 81 | NOT the item-20 bug (81 has that fix). Likely cause, from the text ("S-BUDGET ." = HTML tags stripped): `_processImage` re-read the current mode AFTER its 20-60 s request, so switching translate/explain while it ran stored the explanation as the translation and showed it in translate mode; the Tutor then got the stripped German HTML. Built for 82, not committed: the mode and the picture are pinned at the start, the result goes to its own cache, and is shown only if that mode is still on screen; a result for another picture is dropped. Not reproduced on a phone: please retest the sequence (photo in explain mode, switch to translate during the load, bulb)
| 30 | Tutor → tap on the title goes to Conversation, not back to where it came from (voice note 17.39.59) | built for 82: `_pageBeforeTutor` in `main.dart`; the title tap returns to Conversation, Document, Image, History, Favorites or the Learning list |
| 31 | Markus's answers to the Tutor questions (2 Nov) | (1) keep thinking: "we need correct grammar explanations", only keep the user informed while waiting. (2) split into sentences on the light model ("it is only looking where is a dot"): `AiTask.tutorSentences` → Flash-Lite, done for 83, not committed; note the split also writes the grey translation under each sentence in the picker, now by the light model. (3) he will send the text for "service temporarily unavailable" (waiting). (4) sentence by sentence with a sign that it is still working: built for 83, not committed |
| 32 | Streaming Tutor answer | `generateContentStream` through Firebase AI Logic (`geminiGenerateStream`), `IncrementalJsonArray` takes the finished sentence objects out of the arriving JSON, the page shows each sentence when its closing brace arrives and a green bar with "Ich schreibe noch ..." (EN/DE/HU drafted: "Still writing ...", "Ich schreibe noch ...", "Még írom ...") under them until the answer is complete. Thinking stays on, so the first sentence comes after the thinking (20+ s); streaming shows the writing phase. Once the first sentence is there, the "takes longer" note and "Shorter answer" go away and the shorter request is cancelled. Stall rule: 60 s without a new sentence, or 150 s without the first, ends in the error. An answer the parser cannot use is asked for again in one piece. Charged when the stream ends normally; a cancelled stream is not charged. Unit-tested parser; NOT yet tried on a phone |
| 33 | Markus's text for the Tutor error (2 Nov) | in 83: used instead of "Der Dienst ist vorübergehend nicht verfügbar" on the Tutor's error screen (timeouts, stalled stream, network, split failure); the retry button stays. His Hungarian has a slip: "az magyarázat" should be "a magyarázat"; used as sent, to ask him |
| 34 | A German Word file with Hungarian selected ran for minutes, then "service unavailable" (Markus, 2 Nov, screenshots 18.59.06 / 19.00.30, voice notes 18.59.12 / 19.00.37): "check roughly, maybe with a lighter model, which language it is" and show the standard box before anything is analyzed | built for 84, not committed before this: `detectDocumentLanguage()` asks Flash-Lite (thinking off, 32 output tokens, 25 s limit) for the main language of the file (only the selected pages of a PDF); if it differs from the source language and is one of the page's three languages, the standard "Falsche Sprache" box comes first (Use German / Cancel), no analysis. MIXED, unknown, a failed check, or a language outside the three: the analysis runs as before. Translate mode only; skipped when the document's languages are known from an earlier analysis. Costs a few tenths of a WIU. Tried from the Mac with the same prompt: German picture → DE in 2.3 s, Hungarian → HU in 3.7 s, mostly Hungarian → HU. The long run that ended in \"service unavailable\" is not explained (no log from his phone) |

## Decisions (the user, 28 Oct)

- **Testers start fresh with 200 WIU.** The old balance on the phone is not
  carried over (API.md §7: no migration of the old codes). The alternative
  was Alex crediting each tester by hand.
- **Full recovery flow in 1.0.4**, not later. Without it, an Android
  reinstall gets 409 at register and the user is stuck at 0 WIU.
- **Target: 1.0.4 (78) on Play internal testing today.** The reply to Alex
  goes out after the upload, so the date we give him is already true.

## Markus's feedback on 1.0.4, 29 Oct (build 79)

Sources: his annotations on the update doc, `~/Downloads/text modifications.md`,
screenshots 13.50.34 / 13.51.46 / 13.51.53 and voice note 13.52.46.

**Decisions (Markus):**
- Replace "WIU" with "credits" everywhere the user sees it. Gift code becomes
  top-up code (Aufladecode, feltöltőkód); recovery code becomes backup code
  (Sicherungscode, mentési kód). Internal names (`wiu*` keys, API fields)
  stay.
- Tutor waiting: option A. **Never a light model** (option C: "giving back
  too much wrong stuff"). No streaming (B) for now.
- Tutor rules: no seconds, no time estimates, no infrastructure messages, no
  promise of speed; the bar never reaches 100 % before the answer; a calm
  note and "Shorter answer" when the wait is longer than usual; never
  switch automatically; a real failure shows an error, not an endless wait.
- Roboto Condensed for such dialogs.

**What changed in build 79:**
- `lib/l10n/app_{en,de,hu}.arb`: all of Markus's table texts verbatim.
  Strings outside his tables that still said WIU, Guthaben or code got the
  new terms (drafts, listed below).
- `lib/profile_settings_page.dart`: "Add credits" label, "Top-up code" hint
  in the field (capitals, no autocorrect), "{count} credits added" after a
  redeem (was "Code redeemed: N WIUs", hardcoded).
- `lib/widgets/wallet_dialogs.dart`, `wiu_gate.dart`: `condensedDialog()`
  puts every text in these dialogs in Roboto Condensed. The new-code
  confirmation says "Create new code" instead of "OK".
- `lib/tutor/tutor_page.dart`: a thin bar fills toward 90 % over the usual
  answer time (median of the last 10 accurate answers on this phone, 15 s
  to start) and never further. At 1.5x the usual time the text changes to
  Markus's note and "Shorter answer" fades in. Tapping it shows a spinner
  in the button (Markus's tap "did nothing" before) and starts the
  thinking-off request next to the accurate one; the first answer wins, the
  other is cancelled and not charged. After 150 s with no answer: the error
  with the retry button.

**Drafted DE/HU (not in Markus's tables), for him to check:**

| Key | EN | DE | HU |
|---|---|---|---|
| credits (section header) | Credits | Credits | Kreditek |
| codeForFillingCredits | Add credits | Credits aufladen | Kreditek feltöltése |
| topUpCodeHint | Top-up code | Aufladecode | Feltöltőkód |
| pleaseEnterCode | Please enter a top-up code | Bitte gib einen Aufladecode ein | Kérjük, adj meg egy feltöltőkódot |
| creditsAdded | Top-up code redeemed: {count} credits added | Aufladecode eingelöst: {count} Credits gutgeschrieben | Feltöltőkód beváltva: {count} kredit jóváírva |
| organizeCredits | Manage credits | Credits verwalten | Kreditek kezelése |
| wiuRemaining | {count} credits remaining | Noch {count} Credits übrig | Még {count} kredit van hátra |
| wiuEmptyTitle | Out of credits | Credits aufgebraucht | Elfogytak a kreditjeid |
| wiuEmptyBody | You have no credits left. Please top up on wir-in-ungarn.hu to keep translating. | Du hast keine Credits mehr. Bitte lade auf wir-in-ungarn.hu auf, um weiter zu übersetzen. | Elfogytak a kreditjeid. Kérlek, töltsd fel őket a wir-in-ungarn.hu oldalon, hogy tovább tudj fordítani. |
| wiuLowBody | You are running low on credits. Consider topping up soon on wir-in-ungarn.hu. | Deine Credits werden knapp. Lade bald auf wir-in-ungarn.hu auf. | Fogynak a kreditjeid. Töltsd fel őket hamarosan a wir-in-ungarn.hu oldalon. |
| howItWorksBody | "credit code" → "top-up code" | "Guthabencode" → "Aufladecode", "Guthaben verdienst du dir" → "Credits verdienst du dir" | "Kreditkódot" → "Feltöltőkódot" |
| legalPrivacyBody | "WIU credit system" → "credit system" | "WIU-Guthabensystem" → "Credit-System" | "WIU-kreditrendszer" → "kreditrendszer" |

**Recovery limit date:** the server answers only `RECOVERY_LIMIT_3_PER_30_DAYS`
with no date (API.md §3.4), so the app keeps "try again later", as Markus
asked when no date is available. Alex could add a `retry_after`.

**Item 10, Tutor stability (not built):** both Tutor requests run on
gemini-3.8-flash on "eu". Neither has a retry or a time limit, so when
Google hangs, both hang (23 Oct: 9 of 10 afternoon calls hung or got 429).
Build 79 only bounds the wait at 150 s. Ideas to discuss with Markus, all
EU and no light model: one automatic retry after a 429 or 503; a second EU
region (e.g. a single region like europe-west4 instead of the "eu"
multi-region) as fallback, if 3.8 Flash is offered there.

**Alex's analysis (29 Oct, `~/Downloads/Forditva-Tutor-timeout-analysis-29oct.md`):**
not App Check, no 429/503: every call returned 200, but Vertex "eu" took
p50 89 s for a Tutor answer (25-33 s on 23-27 Oct) and 62 s for the
sentence split at 12:40 UTC. The app had no time limit. `europe-west4`
still answers 404 for this project, so no regional fallback.
His five proposals and where they stand:

| # | Alex | Status |
|---|---|---|
| 1 | Stream the answer | = option B; Markus said not now. Ask Markus |
| 2 | 75 s timeout per call, own message, retry | build 79 has 150 s for the answer and now 90 s for the split; the error is the general one. Own message needs Markus's DE/HU |
| 3 | Thinking off by default (31 s vs 58 s) | contradicts Markus 2026-10-09 (accurate by default). Ask Markus; a thinking budget (1,024) is the middle way |
| 4 | Sentence split on Flash-Lite | Markus: never a light model. Ask him if that covers the split (it also translates each sentence for the picker) |
| 5 | maxOutputTokens 32768 → 4096 | not as proposed: his own probe had 3,563-4,253 output tokens, so 4096 would cut answers into invalid JSON and trigger the retry. 8192 at most |

**Alex's client update (29 Oct):** `initialize()` keeps the local balance
on proxy HTML errors and any 5xx; the client retries a dead recovery
request once. Dropped in unchanged; compiles, analyze clean, 13 tests pass.
Our own recovery retry in `token_balance.dart` removed (it would have made
a third attempt). The retry itself is not unit-testable on the Mac (the
device id needs Android or iOS).

## What changed

- `lib/services/forditva_token_client.dart`: Alex's file, unchanged, so
  his next versions diff cleanly.
- `lib/services/token_balance.dart`: now wraps his client. The balance is
  `granted_total - spent_total`. Each AI call still spends its exact
  fractional cost. Whole WIU go to `recordConsumption`, and the fraction
  waits for the next spend (the "round down" rule of API.md §5).
  Sync runs at start and on resume when the last sync is 8 hours old
  (`main.dart`). The welcome-grant code and the 100 WIU local grant are gone.
- `lib/widgets/wallet_dialogs.dart`:
  - First-launch choice: "Start with 200 WIU" or "I have a recovery code".
  - The recovery code dialog: shown once, groups of 5, copy button.
  - The restore dialog.
  - Rotating the recovery code ("New recovery code" in Settings).
- `lib/widgets/wiu_gate.dart`: with no wallet, an AI action opens the
  first-launch choice first. With a refused credential, it opens the
  restore dialog.
- `lib/profile_settings_page.dart`:
  - Redeem goes through the wallet.
  - New error texts: one-hour lock after 5 wrong codes, and "already added".
  - Two links: "Restore with recovery code" and "New recovery code".
- Removed `prepaid_token_service.dart`, `welcome_grant_service.dart` and
  the empty `PREPAID_*` lines in `.env`.
- `device_info_plus` ^11.5.0 (for the iOS id). Version 13 needs `win32` 6,
  but the project overrides it to 5, and that broke compilation.
- Version 1.0.4+78.

## Three gaps in Alex's client (worked around in our code, reported to him)

1. `initialize()` catches `SocketException`, but the `http` package throws
   `ClientException` when there is no connection. An offline start would
   throw instead of keeping the balance. Our wrapper catches all three.
2. After `RECOVERY_REQUEST_ID_ALREADY_USED` or
   `RECOVERY_SESSION_SUPERSEDED`, the client keeps the pending recovery
   request, so every retry fails the same way. Our wrapper deletes it and
   tries once more with a new request.
3. `recordConsumption` takes whole WIU only. We keep the fraction in the
   app and send whole WIU. This is the rounding rule he asked us to confirm.

## Testing

- `flutter analyze lib test`: no issues.
- `flutter test`: the new `test/token_balance_test.dart` passes (11 tests).
  It covers fractional spends, the sync total, the 8-hour rule, offline,
  401, redeem with the total, "already added", and 400 / 429 lock /
  429 proxy / 502. `widget_test.dart` fails before and after this change:
  it is the old Flutter counter template and doesn't test this app.
- Phone test against the live server, 29 Oct, Xiaomi, debug build signed
  with the sideload key (fresh install; there was no Forditva on the phone):
  - First launch showed the welcome dialog. "Start with 200 WIU" registered
    a wallet, showed the recovery code once, and Settings showed
    "200 WIUs remaining".
  - On restart the welcome dialog did not come back: the wallet is stored.
  - A made-up gift code (`ABCDEFGH`): the server answered
    `400 INVALID_OR_USED_CODE` and the app showed "This code is invalid or
    has already been used". It counted 2 wrong attempts, below the lock at 5.
  - Uninstall, reinstall, "I have a recovery code" with the saved code: the
    wallet came back.
  - Not tested yet:
    - a successful redeem (needs a test code);
    - an AI call lowering the balance and the sync total (the fresh install
      has a new App Check debug token, not registered);
    - the 409 path ("Start new" after a reinstall);
    - an offline start.

## New texts (EN final; DE/HU drafted, for Markus to correct)

| Key | EN | DE | HU |
|---|---|---|---|
| walletWelcomeTitle | Welcome to fordítva | Willkommen bei fordítva | Üdvözlünk a fordítvában! |
| walletWelcomeBody | You start with 200 free WIU. Used fordítva before? Bring your WIU back with your recovery code. | Du startest mit 200 kostenlosen WIU. Hast du fordítva schon genutzt? Mit deinem Wiederherstellungscode holst du dein Guthaben zurück. | 200 ingyenes WIU-val kezdesz. Használtad már a fordítvát? A visszaállító kódoddal visszakapod az egyenlegedet. |
| walletStartNew | Start with 200 WIU | Mit 200 WIU starten | Kezdés 200 WIU-val |
| walletHaveRecoveryCode | I have a recovery code | Ich habe einen Wiederherstellungscode | Van visszaállító kódom |
| walletNeedsInternet | Please connect to the internet once to set up your WIU balance. | Bitte verbinde dich einmal mit dem Internet, um dein WIU-Guthaben einzurichten. | Kérlek, csatlakozz egyszer az internethez, hogy beállítsuk a WIU egyenlegedet. |
| recoveryCodeTitle | Your recovery code | Dein Wiederherstellungscode | A visszaállító kódod |
| recoveryCodeBody | Write this code down and keep it safe. If you reinstall the app or get a new phone, it brings your WIU back. We show it only once. | Schreib dir diesen Code auf und bewahre ihn gut auf. Wenn du die App neu installierst oder ein neues Handy hast, bekommst du damit dein WIU-Guthaben zurück. Wir zeigen ihn nur einmal an. | Írd fel ezt a kódot, és őrizd meg jól. Ha újratelepíted az alkalmazást, vagy új telefonod lesz, ezzel visszakapod a WIU egyenlegedet. Csak egyszer mutatjuk meg. |
| recoveryCodeDone | I wrote it down | Ich habe ihn notiert | Felírtam |
| recoverTitle | Restore with recovery code | Mit Wiederherstellungscode zurückholen | Visszaállítás kóddal |
| recoverNeededBody | This phone already had a WIU balance. Enter your recovery code to get it back. | Auf diesem Handy gab es schon ein WIU-Guthaben. Gib deinen Wiederherstellungscode ein, um es zurückzuholen. | Ezen a telefonon már volt WIU egyenleg. Add meg a visszaállító kódodat, hogy visszakapd. |
| recoverHint | 25-character code | Code mit 25 Zeichen | 25 karakteres kód |
| recoverButton | Restore | Zurückholen | Visszaállítás |
| recoverDone | Your WIU balance is back | Dein WIU-Guthaben ist zurück | Visszakaptad a WIU egyenlegedet |
| recoverLimit | This code was used 3 times in 30 days. Please try again later. | Dieser Code wurde in 30 Tagen schon 3-mal verwendet. Bitte versuche es später erneut. | Ezt a kódot 30 napon belül már 3-szor használták. Kérlek, próbáld újra később. |
| recoverDeviceLinked | This phone already belongs to another WIU balance. | Dieses Handy gehört schon zu einem anderen WIU-Guthaben. | Ez a telefon már egy másik WIU egyenleghez tartozik. |
| codeLockedHour | Too many wrong codes. Please try again in one hour. | Zu viele falsche Codes. Bitte versuche es in einer Stunde erneut. | Túl sok hibás kód. Kérlek, próbáld újra egy óra múlva. |
| codeAlreadyAdded | This code was already added to your balance. | Dieser Code wurde deinem Guthaben bereits gutgeschrieben. | Ezt a kódot már jóváírtuk az egyenlegeden. |
| newRecoveryCode | New recovery code | Neuer Wiederherstellungscode | Új visszaállító kód |
| newRecoveryCodeConfirm | You get a new recovery code, and your old one stops working. Continue? | Du bekommst einen neuen Wiederherstellungscode, dein alter funktioniert dann nicht mehr. Fortfahren? | Új visszaállító kódot kapsz, a régi pedig nem működik tovább. Folytatod? |

## 6. Conversation: the white side refreshed on a language change

**Markus (video, 29 Oct):** when he changes the language on the dark side
(EN to HU), the German text on the white side also renews. It should stay;
only the dark side should change.

**Found:** both cards used one busy flag (`_isTranslating` in
`lib/textpage.dart`). A busy card hides its text and shows the loader, so
every translation blanked both cards, also the one whose text doesn't
change. The text came back unchanged, but it looked like a re-translation.
The same happened after speaking: the side you spoke into went blank until
the translation arrived.

**Changed:** one flag per card (`_topBusy`, `_bottomBusy`). Only the card
that gets the new text clears and shows the loader. The other keeps its
text: after a language change, and after speaking, where your own words
now stay visible. The swap button still refreshes both cards.

**Testing:** `flutter analyze` clean. Not seen on the phone yet: AI calls
fail on the current debug install until its App Check debug token is
registered.

## Round of 2 Nov, evening (build 85)

35. **Copy and Share gave HTML.** In explain mode the result is stored as HTML,
    so Copy and Share put `<p>`, `<strong>`, `<li>` on the clipboard (Markus's
    screenshot and voice note, 21:47). Now plain text: paragraphs, bullets for
    lists. A translation gives the translated lines instead of the raw
    segment list. `lib/image_page.dart`, `_copyableText()`.
36. **"Shorter answer": tested on the phone over 3G.** The button appears, a
    tap starts the request (spinner). On 3G it took about 30 s, so no visible
    gain; we could not tell which request delivered the answer. Changes: the
    button appears after at most 10 s (was 1.5x the usual time, 22 s without
    history; Markus then asked for 20 s, see 39); if the fast request fails, the button comes back; log lines for
    each step.
37. **Tutor from the Learning history asked again** (Markus, 21:13). Answers
    were already saved, but the Understanding answer is saved per level and the
    page opened at the current slider level, so a different saved level meant
    no hit. Now the slider goes to the saved level. The same sentence from
    another page also uses the saved answer when the explanation language
    matches. Not covered: a sentence picked from "Choose sentences".
38. **Monthly cleanup of the history** (Markus): entries older than 3 months
    are deleted, once a month, on the first read after the app starts
    (`LearningStore.purgeOld`, tested).

39. **Build 86, Markus's two points (22:19 and 22:20).** (a) "Shorter answer"
    appears after a flat 20 s (the first sentence usually comes after about
    14 s). (b) The crop instruction ran to 5 lines on his phone and below the
    screen. It is now sized to the width so that it is 3 lines (title 1, body
    2), whatever the system font size (`cropInstructionScale`, tested).

## Still open

- Phone test against the live server (see the plan's checklist).
- A test gift code from Alex.
- After the release: Markus or Alex switch off the WordPress plugin
  `app-translation-tokens` and revoke `PREPAID_API_KEY`. Also remove the
  `PREPAID_*` lines from the GitHub `DOTENV` secret.

## Reply to Alex (draft, send after the AAB upload)

Hi Alex, thanks for the files. 1.0.4 (78) switches the app to the Token
Server and is on Play internal testing since <time>. Markus can test as soon
as Play shows the update.

- New install: the app asks "start with 200 WIU" or "I have a recovery
  code" before it registers, as your client recommends. It shows the
  recovery code once after registering.
- Gift codes go to /v3/redeem with the lifetime total. Sync runs at start
  and on resume when the last sync is 8 hours old.
- Spending: the app counts the exact fraction and sends the total rounded
  down, as proposed in API.md §5. Confirmed.
- The WordPress calls, the key and the local 100 WIU are gone from the app.
  You can switch off the plugin and revoke the key once Markus has 1.0.4.
- Old balances: testers start fresh with 200 WIU (no migration).

Three things in `forditva_token_client.dart`. I worked around them in the
app without changing your file, so you may want to fix them for the next
version:

1. `initialize()` catches `SocketException`, but `package:http` throws
   `ClientException` when offline, so an offline start throws.
2. After `RECOVERY_REQUEST_ID_ALREADY_USED` or
   `RECOVERY_SESSION_SUPERSEDED`, the pending recovery keys stay stored, so
   every retry sends the same request_id and fails again.
3. `recordConsumption` takes whole WIU. Fine for us, we keep the fraction
   in the app.

Could you send me a test gift code (500 WIU is enough), so I can test
redeem without using one of Markus's?

## Update for Markus (draft, send when the round is done)

Hi Markus, 1.0.4 is on Play internal testing. Your new gift codes work now:
the app uses Alex's Token Server instead of the old WordPress codes.

- On the first start, the app asks: start with 200 free WIU, or enter a
  recovery code. Your old balance on the phone doesn't carry over; you
  start with 200 WIU.
- After that, the app shows a 25-character recovery code once. Please
  write it down: with it you get your WIU back after a reinstall or on a
  new phone. Settings has "Restore with recovery code" and "New recovery
  code".
- Conversation: changing the language on the dark side no longer
  refreshes the white side. Only the side with the new language changes.
  After speaking, your own words also stay visible while the translation
  loads.
- Please check the German and Hungarian texts for the new dialogs (table
  attached) and send me corrections.
