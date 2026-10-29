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
| 4 | DE/HU texts for the new dialogs | drafted (du/te), Markus to correct |
| 5 | Gift code for the phone test | ask Alex for a test code |
| 6 | Conversation: changing the dark side's language also blanked and refilled the white side (Markus's video, 29 Oct) | fixed, in 1.0.4; not seen on the phone yet |

## Decisions (the user, 28 Oct)

- **Testers start fresh with 200 WIU.** The old balance on the phone is not
  carried over (API.md §7: no migration of the old codes). The alternative
  was Alex crediting each tester by hand.
- **Full recovery flow in 1.0.4**, not later. Without it, an Android
  reinstall gets 409 at register and the user is stuck at 0 WIU.
- **Target: 1.0.4 (78) on Play internal testing today.** The reply to Alex
  goes out after the upload, so the date we give him is already true.

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
