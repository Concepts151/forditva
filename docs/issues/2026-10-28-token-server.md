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
| 17 | Every AI call failed with "Firebase AI Logic genai config not found" on 79 (29 Oct evening) | Alex: since he enforced App Check for AI Logic, the standard 1-hour token counted as reused (metric CONSUMED, app id UNKNOWN), answer 400. He set enforcement back to monitoring; 79 translated again at 22:25. Build 80: `useLimitedUseAppCheckTokens: true` in `gemini_firebase.dart` (the only place a model is made). Must be on Play before 2 Nov, when Google enforces App Check for AI Logic. Tested from Play, not a debug build (the user's call). iOS later: flutterfire issue 18718 (limited-use token is a standard one on iOS) |

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
