# Markus's feedback round, 2026-10-12

One entry per item. Each records what Markus asked for, what we found and
changed, and every decision, so the "Update for Markus" section at the
bottom can be sent once the round is done.

| # | Where | Issue | Status |
|---|---|---|---|
| 1 | Backend | Specification for Andy to build the backend API (keys off the phone) | spec written but **not shared** (kept internal); Alex got a short endpoint + WIU brief instead |
| 2 | Conversation mic | "Pling" sound on every pause (even in infinity mode); no punctuation, spoken "point" ignored (test video of v1.0.1+71) | done (20 Oct): both mics record and Gemini transcribes, see item 10 |
| 3 | Tutor / text AI | Try DeepSeek for the Tutor and text-only translation; provider must be selectable in code | switch built (default unchanged: Gemini), comparison tool ready, waiting for Markus's 10 examples |
| 4 | AI architecture | Central AI configuration: model + own prompt per task, 10 level bands, weekly prompt updates without app release | review and plan sent, waiting for Markus's decisions |
| 5 | Image page / server | Markus's FastAPI + LibreOffice conversion server document: good to go? What does Andy need? | server package delivered (16 Oct), waiting for Andy to deploy |
| 6 | Token Server / TTS | Alex's API contract (v3) and Text-to-Speech function design, with questions | answers drafted (16 Oct) |
| 7 | Release | Markus: current status, what is missing, when is Android done? | status + timeline written (16 Oct), Play admin access needed |
| 8 | Release | Markus (19 Oct): go live on Play (and App Store) by Wed 21 Oct with the website changes? | answered: not possible; closed test by Wednesday if admin access today, public ~mid-November |
| 9 | Read-aloud | Alex's `synthesizeSpeech` function deployed: switch the app to it, new voices, error rules, test | done and tested on the dev phone (20 Oct); old key can be revoked once this build ships (item 10) |
| 10 | Voice input | Replace the phone recognizer and Cloud STT | done (20 Oct): Gemini Flash-Lite via Firebase, no key, tested on the Xiaomi |
| 11 | Translation | Natural instead of literal plain translation; a dropped last line found in testing | done (20 Oct), tested on the Xiaomi |
| 12 | Tutor | Markus's "Sprachlevel" ring, always without a number | done (20 Oct), not yet seen on screen |
| 13 | Release | Play Console access granted; app has production access | keys removed from the bundled `.env`; AAB next |
| 16 | AI / privacy | Markus (22 Oct, via Alex): all AI in the EU only; DeepSeek out of every build, Gemini to Vertex AI with an EU location | done (23 Oct): DeepSeek out, Gemini on Vertex AI "eu", tested on the phone; in +73 |
| 17 | Documents | Andy deployed the conversion server (23 Oct) | app switched to it; DOCX/XLSX/ODT/ODS/DOC tested from the Mac; in +74 |

---

## 1. Backend API specification for Andy

**Markus asked:** a specification to give Andy for what we need to set up
the APIs on the backend.

**Background:** the Gemini, Speech-to-Text and Text-to-Speech API keys are
bundled in the app; anyone can extract them from the APK (that is how
`.env` was recovered on 2026-10-02). The shared `PREPAID_API_KEY` for the
WordPress API is exposed the same way. `OPENAI_API_KEY` and
`LINGVANEX_API_KEY` are unused.

**What we found:** besides the keys, the **WIU balance is entirely on the
phone** (`TokenBalance`, local storage key `token_balance_wiu`; the app
deducts it itself). Prepaid codes and the welcome grant are only verified by
the WordPress code list; the WIU is then added locally. Voice input
(Speech-to-Text) is not charged at all today.

**What we produced:** `docs/backend-api-spec.md`, version 2 (and the Word
copy for Markus, `Forditva-backend-API-spec-2026-10-12.docx`). The server
on Andy's machine holds the Google keys **and** every device's WIU balance:
devices register and get a secret device token (100 WIU welcome grant once
per hardware id), every Gemini / Speech / Text-to-Speech request is checked
against the balance, forwarded unchanged and charged with the app's current
formulas, and prepaid codes are redeemed through the server (which calls
the WordPress code list with its own key). Also: data model, endpoints,
charging rules with the exact constants, errors, abuse limits (mainly on
the free welcome grant), configuration, admin tasks, privacy, 13
acceptance tests, rollout.

**Decisions** (2026-10-12):

- *No Firebase.* A first version used Firebase App Check to accept only
  the genuine app. Replaced by charging every request against a
  server-side WIU balance: a fake client can only spend credits someone
  paid for. The only free money left is the 100 WIU welcome grant, which
  is limited per device, per IP and per day.
- *Roles (Markus, 2026-10-12):* **Alex** (Aliaksandr), the web developer
  who runs the headless WordPress + Next.js and replaced Shahin Alam,
  **builds** the API from the spec; **Andy**, the Linux admin, **hosts**
  it. Shahin built only the prepaid code list; Kayode added the app's
  verify/finalize and welcome-grant endpoints. The app team changes the app
  afterwards.
- *A normal long-running service, not a WordPress plugin or serverless
  function:* Tutor requests take up to 2 minutes, uploads up to 20 MB
  (Vercel caps request bodies at 4.5 MB), conversion needs LibreOffice.
- *Thin pass-through:* the app keeps building the Google requests (prompts
  change often); the server does not re-implement them.
- *The balance belongs to a secret device token*, not to the ANDROID_ID
  (which other apps can read); the hardware id only prevents a second
  welcome grant.
- *Existing testers' balances: Markus decides* (spec section 14).
- *Design changed (Alex, after talking to Markus, 2026-10-12):* Alex
  builds a small key proxy on top of Markus's **Token Server 3.0**
  package. The app calls it with its wallet credentials and the proxy
  forwards to Google. **Token counting stays in the app** (local counter,
  sync every 8 hours), so the server-side balance and charging in our
  spec v2.1 are superseded. We sent Alex the endpoint list (5 Google
  calls, none streamed; unused OpenAI/Lingvanex keys get deleted).
  Risk raised: the proxy does not check the balance per request, so we
  suggested a per-wallet daily cap on the server.
- *The full spec (`docs/backend-api-spec.md` v2.1) was never sent* to
  Markus, Alex or Andy, to keep things simple. It stays as internal
  reference only. Alex instead got
  `Forditva-Google-API-calls-for-Alex-2026-10-12.docx`: the 5 Google
  calls with request bodies, no streaming, body/timeout limits, the
  non-Google keys, and (kept simple at the user's request) how the 100
  WIU welcome grant works, how it can be abused (offline trick, ANDROID_ID
  not unique, local balance editable, WordPress key in the APK, endless
  new wallets through the proxy) and suggestions for his server
  (server-side grant once per wallet and device, fail closed, per-IP
  limits, daily cap, server-only WordPress key). The WIU counting details
  and price constants were left out of his copy.

**Markus's assessment (2026-10-12, AI-written, also sent to Alex):** no
proxy and no further changes until (1) Alex confirms Token Server 3.0 works
with the app's local token calculation and never handles AI requests, and
(2) we check whether **Firebase AI Logic** fits the Gemini calls and how
Speech-to-Text and Text-to-Speech can be secured without usable keys.
Intended split: the app makes all AI calls and calculates usage; the Token
Server only manages balances.

**WIU calculation sent to Markus and Alex (2026-10-12):** 1 WIU = $0.0025;
Gemini WIU = (input x 0.00012 + output incl. thinking x 0.001) x 1.30 for
all Gemini calls; Speech-to-Text 0; Text-to-Speech characters x 0.0016 (no
margin); Hungarian punctuation not charged. Examples: translation ~0.05,
read-aloud 100 chars 0.16, spoken turn ~0.2-0.3, Tutor accurate ~5-10 WIU.
Flagged the 3.8 Flash under-charge and the correct constants. No usage data
exists for calls per user; suggested WIU-based daily caps (about 200 per
wallet, about 50 for welcome-grant-only wallets) to review with real data.

**Firebase AI Logic check (2026-10-12):** assessment in
`docs/reviews/2026-10-12-firebase-ai-logic-assessment.md` (Word copy
`Forditva-Firebase-AI-Logic-assessment-2026-10-12.docx`). Verdict: suitable
for all Gemini calls (system instructions, JSON, thinking, inline
images/PDF up to 20 MB, `usageMetadata` incl. `thoughtsTokenCount`,
Flutter `firebase_ai` 4.0.0); the Gemini key stays at Google; no fee for
AI Logic; 100 requests/min per user by default; App Check mandatory from
2 Nov 2026. Speech-to-Text: move to Gemini audio transcription (no key).
Text-to-Speech: not in AI Logic; recommended a small Firebase function with
App Check holding the WaveNet key (option A) over Gemini TTS (preview,
2.5-9x the price). Blockers: Firebase project under Markus's account
(Blaze), Play Console for Play Integrity, sideloaded test APKs need relaxed
verdict or debug tokens. WordPress key still to move to the Token Server.

**Firebase set up by Alex (2026-10-13):** project `forditva-151`, AI Logic
on with the Gemini Developer API, App Check with Play Integrity registered
(not enforced; enforced automatically for AI Logic from 2 Nov 2026). Both
apps were registered as `com.mycompany.forditva` (wrong). Sent him: Android
`hu.wirinungarn.forditva`, iOS `hu.wirinungarn.forditva3`; tester signing
key SHA-256 `32:B6:75:A1:F3:A7:4E:7E:AC:4C:82:61:05:BF:94:1F:87:C3:ED:C8:28:40:96:2E:4F:CF:AD:3D:F3:65:74:F9`,
SHA-1 `30:E0:7E:65:D0:23:80:97:77:A4:F4:0C:B9:32:0C:EF:5E:47:1A:D8` (read from
the v1.0.1+71 APK); the `07b92e02...6eef` fingerprint is not ours (not the
sideload key, not Kayode's old debug key `037e7f94...401c`). Upload key
(Kayode's, `1F:51:05:AD...8F:75`) is not on this Mac, only in GitHub
secrets; for Play Integrity the relevant one is Google's app signing key
from the Play Console. Apple Team ID in the Xcode project: `75Y9R496R9`
(Markus to confirm it is his team). Debug tokens: generated by the app
once it has the Firebase config files, so they follow his files.

**Config files from Alex (2026-10-14):** `google-services.json` and
`GoogleService-Info.plist`, stored in `.deploy/firebase/` (gitignored).
Android app `1:851863893438:android:c740e257fb79717cefb5ef`, package
`hu.wirinungarn.forditva`: correct, copied into `lib/firebase_options.dart`.
iOS app registered as `hu.wirinungarn.forditva` although we sent
`hu.wirinungarn.forditva3`: left as placeholder until Markus confirms iOS
and Alex fixes the bundle id. Debug builds now use the App Check debug
provider (release builds keep Play Integrity); the dev phone's debug token
still has to be registered in the Firebase console. Not yet run on the
phone (not connected).

**Price check (2026-10-12):** a live Gemini call shows the aliases resolve
to `gemini-flash-latest` = **gemini-3.8-flash** and
`gemini-flash-lite-latest` = **gemini-3.5-flash-lite** (`modelVersion` in
the response). Google's pricing page (ai.google.dev/gemini-api/docs/pricing):
3.8 Flash $0.75 input / $3.75 output per 1M tokens until 31 Dec 2026,
doubling to $1.50 / $7.50 from 1 Jan 2027; 3.5 Flash-Lite $0.30 / $2.50.
`gemini_cost.dart` charges 2.5 Flash prices ($0.30 / $2.50) for every
call. Flash-Lite (text translation) is covered. Every `gemini-flash-latest`
call (photo/PDF, Tutor, language detection, Hungarian punctuation) is
**undercharged** even with the 30 % margin: input at about half the real
cost, output at about 87 %. From 2027 the gap grows to about a quarter and
under half. The docx for Alex now says the rates may change and asks him
to keep them configurable.

**Open questions for Markus (sent separately, not via the spec):**

1. Gemini prices: charge the real price of the model in use (3.8 Flash,
   rising in January), or switch the heavy calls to a cheaper model?
2. Voice input: free today, Google charges about $0.024 per minute.
   Charge it (proposal 0.208 WIU per second = Google + 30 %)?
3. Read aloud: add the 30 % margin like Gemini?
4. Testers' current phone balances when wallets arrive: carry over, or
   start fresh with the welcome grant?

---

## 2. Conversation mic: restart sound and no punctuation

**Markus reported** (video, v1.0.1+71, Samsung): a "pling" plays every
time he pauses, also with the infinity button on, and must go. The text has
no full stops or commas; saying "point" does nothing. "You need to ask the
AI where it will set points and commas."

**Root cause:** the conversation mic uses the phone's built-in recognizer.
Android ends its session after each pause, the panel restarts it to keep
listening, and Android plays its start sound on every restart (no option
in `speech_to_text` to silence it). The built-in recognizer returns no
punctuation, and the Gemini punctuation added on 2026-10-09 only runs in
the cloud path, which his phone never uses. Not a bug: his English
comments came out as German-ish text because German was selected; no text
was lost.

**Proposed fix** (details in
`docs/reviews/2026-10-12-models-cost-speech-review.md`): record audio in
the app and transcribe it with Gemini 3.5 Flash-Lite. Tested live: correct
punctuation in HU, DE and EN, a dictated "Punkt" becomes a full stop, 2 to
3.5 s, about 18 times cheaper than Cloud STT. One risk found: on silence
Gemini invented a sentence, so audio is only sent when the mic level shows
speech.

**Decision:** pending, waiting for the user's go-ahead.

---

## 3. DeepSeek for the Tutor and text translation

**Markus asked** (with his cost comparison `compare LLMs.md`): run the Tutor
and every text-only translation through DeepSeek to save money, and make
the provider selectable in code even if DeepSeek is not used at first. His
own proposal: test 10 identical Tutor examples first, no changes to the
Tutor or WIU charging before the evaluation.

**Checked:** DeepSeek's price list (2026-10-12) matches his numbers:
`deepseek-flash` (V4.1) $0.15-0.30 input, $0.003-0.006 cached input,
$0.60-1.20 output per 1M tokens; peak hours 06:00-10:00 UTC (08:00-12:00 in
Hungary) cost double. The DeepSeek key works.

**Built (default behaviour unchanged, every job still on the same Gemini
model):**

- `lib/services/ai/`: `ai_models.dart` (model list with prices, WIU =
  real price + 30 %; Gemini keeps today's constants), `text_ai.dart` (one
  request format for Gemini REST and the OpenAI-style API DeepSeek and many
  other hosts use; pure Dart), `ai_router.dart` (`aiRoutes`: one line per
  job decides the model: translate, explain, detectLanguage, tutor,
  tutorSentences; charges WIU at that model's price).
- Tutor (`tutor_service.dart`) and `GeminiTranslator` now go through the
  router; Tutor prompts, JSON checks and parsing moved to
  `lib/tutor/tutor_core.dart` so the comparison tool uses the app's exact
  code. The Google Dart SDK (`google_generative_ai`) is no longer used and
  was removed.
- Found while testing: Gemini 3.5 Flash-Lite rejects "thinking off"
  (HTTP 400), so models now carry a flag and the setting is left out for
  them. DeepSeek's JSON mode cannot return a top-level array; the Tutor
  parser now also accepts a single sentence object or an object wrapping
  the array.
- `tool/llm_compare.dart` + `tool/llm_compare_examples.txt`: runs each
  example through all three Tutor tabs on Gemini 3.8 Flash (accurate and
  fast), DeepSeek Flash (no thinking) and Gemini 3.5 Flash-Lite, plus
  HU->DE translation, with the app's prompts, checks and one retry; writes
  `build/llm_compare/report.md` (time, tokens, real cost, full answers).
- Tests: `test/text_ai_test.dart` (prices, response parsing, Tutor JSON
  shapes). `flutter analyze` clean apart from 2 old notices.

**Trial run (4 placeholder sentences, real cost without margin, per 1,000
requests):** Understanding: Gemini accurate $4.36, fast $2.41, DeepSeek
$0.81, Flash-Lite $1.19. Decoding: $9.54 / $3.00 / $0.22 / $1.30. Focus:
$11.18 / $4.52 / $0.93 / $2.26. DeepSeek also faster than Gemini accurate
(1.7-4.5 s vs 8-19 s). Translation: DeepSeek $0.06 vs Flash-Lite $0.07 per
1,000, Flash-Lite slightly faster. First quality signal: Flash-Lite wrote
"elmenyi" (not a word). Word copy:
`Forditva-Tutor-model-comparison-TRIAL-2026-10-12.docx`.

**Markus's decision (2026-10-12):** images and everything with speech stay
on Gemini; translations and the Tutor should try DeepSeek; switching must
stay a one-line change (it is: `aiRoutes` in `ai_router.dart`).

**Benchmark (Markus's bundle `forditva_tutor_llm_comparison_bundle.zip` +
`Sentence for checking normal translation.txt`):** separate program
`tool/tutor_benchmark/` (README there) following his
`DEVELOPER_HANDOFF_EN.md`: 120 Tutor runs (10 sentences, Mode 1 at levels
05/30/60/90, Decoder, Mode 3; German) plus 8 translations (HU->DE, HU->EN,
DE->HU, EN->HU) on pinned `gemini-3.8-flash` / `gemini-3.5-flash-lite` and
`deepseek-flash`, thinking off, app prompts (his handoff files are
byte-identical to the app's). Results with raw responses, token data,
verified USD, named and blind side-by-side HTML, score sheet:
`~/Downloads/Forditva-Tutor-benchmark-2026-10-12.zip`. All 128 runs passed
the automatic checks. Per 1,000 (no margin): Mode 1 Gemini $2.19 vs
DeepSeek $0.27, Decoder $3.03 vs $0.11, Mode 3 $4.59 vs $0.51 (DeepSeek
off-peak; peak doubles). DeepSeek faster on the Tutor (1.7-4.8 s vs
2.3-6.7 s), slower on long translations (2.0-3.9 s vs 1.2-1.6 s). Mode 1:
Gemini changes the selected terms almost completely between L05 and L90
(6 % overlap), DeepSeek keeps 40 %. Found: DeepSeek's JSON mode returns a
single object instead of the required array (19 of 40 Mode 1 answers);
without it 40/40 correct, so the app's DeepSeek connection no longer sends
`response_format`. Grammar quality: Markus reviews.

**Open:** Markus's quality review of the benchmark; the
DeepSeek key must not ship in the app (it is in the bundled `.env` for
testing only: no APK builds until it is moved out) and DeepSeek needs a
keyless route plus a privacy-policy decision (data processed in China)
before production.

---

## 4. AI configuration and prompt management

**Markus asked** (2026-10-13, with `docs/llms/FUTURE_IMPLEMENTATION_SPEC_EN.md`
and `FORDITVA_Prompt_Library_Flutter_Integration_v1_1.zip`): per task a
model and a model-specific prompt, ten Tutor Mode 1 level bands (exact
level kept), prompt updates about weekly without a new app version; AI
calls and WIU stay in the app, the server only distributes configuration,
no AI proxy. Review with "your programming AI" first: implementation,
changes, risks, simplifications.

**Found:** about half exists already (`aiRoutes`, per-model prices,
Gemini/DeepSeek adapters, `tutor_core.dart`). Not yet on the switch:
photo/PDF (`processImage`), document questions, segment re-translation,
Hungarian punctuation. His library's Tutor prompts equal the app's (Mode 1,
Decoder, DE profile 100 %, Mode 3 99 %), but it adds new layers (shared
rules, language/direction profiles, level bands) and rewritten prompts for
translation (natural vs the app's strict literal one), detection,
photo/PDF, document Q&A and punctuation (output formats "TO_CONFIRM"; the
photo prompt would lose the languages line the app reads). Three app text
tasks are missing from his list (sentence picker, segment re-translation,
old explain mode); the app has one photo/PDF path, not two.

**Reply sent:** `docs/reviews/2026-10-13-ai-configuration-review.md`,
Word copy `Forditva-AI-configuration-review-2026-10-13.docx`: code audit,
architecture, compatibility (DeepSeek text only), changes to his package
(baseline = today's prompts as default, his texts as "library v1"
candidates), Firebase Remote Config instead of a signed server (1,000,000
characters limit, bundle 224 KB, built-in versions/rollback/tester
conditions), security (DeepSeek key conflict: test only, Firebase function
exception, or key in app), risks, phases with rough estimates (phase 1
about 4-6 days, phase 2 about 3-5 days), six decisions (DeepSeek key,
Remote Config vs Alex server, translation style, prompt approval, 200 vs
100 WIU welcome grant, iOS).

**Decision:** pending Markus.

---

## 5. Document-to-PDF conversion server

**Markus sent (2026-10-13):** `Forditva_Document_to_PDF_Conversion_Server.md`,
a FastAPI + headless LibreOffice service (`POST /convert/to-pdf`, field
`file`, `X-API-Key`, 25 MiB, 2 parallel conversions, 90 s timeout,
systemd on 127.0.0.1:8000 behind an HTTPS proxy). It mentions an existing
`/convert/to-text` FastAPI service on his side.

**What we found:** technically sound, but not deployable as written:

- The shared `X-API-Key` would have to be in the APK (his own section 5
  warns against it; August decision: no static key in the app). Replace
  with Firebase App Check token verification against `forditva-151`;
  keep the key only for Andy's curl tests.
- 25 MiB is above what Gemini takes (20 MB per request, base64 adds a
  third): suggested 15 MB upload / 14 MB PDF, or his earlier 4 MB.
- No rate limit yet; fonts for Calibri/Cambria metrics missing.
- `.txt` needs no server (the app sends it to Gemini directly).

**Decision proposed:** use his Python server as the only implementation
and remove Kayode's Node `conversion-service/`; the app switches to his
path `/convert/to-pdf`.

**Sent:** `docs/reviews/2026-10-14-conversion-server-reply.md`, Word copy
`Forditva-conversion-server-reply-2026-10-14.docx`, with Andy's five
tasks (subdomain + HTTPS proxy with 16 MB body / 120 s timeout, install
in Docker or systemd, env file with project ID and test key, port 8000
closed, send the URL).

**Open (Markus):** 15 MB or 4 MB; same FastAPI app as `/convert/to-text`
or separate. To verify when building: App Check tokens checked with only
the project ID, no service account.

**Markus decided (2026-10-14):** 15 MB upload, 30 MB PDF, 2 parallel,
90 s; separate FastAPI service at `POST /convert/to-pdf`; App Check via
public JWKS (signature, expiry, issuer, audience, app ID), no service
account; API key only for Andy's internal tests, never through the public
address; Andy prepares domain, HTTPS, proxy (16 MB, 120 s, rate limit),
Docker, fonts, 2 GB RAM. We checked his Gemini numbers: the direct REST
call allows 100 MB per request and 50 MB PDFs, so 30 MB is fine today;
Firebase AI Logic caps a request at 20 MB (PDF about 14 MB), so the app
must check the size per route once Gemini moves there. Told him so.

**Delivered (2026-10-16):** `conversion-service/` rewritten in Python
(`server.py`, `requirements.txt`, `Dockerfile`, `.env.example`, `README.md`
for Andy, `test_server.py`), Node files removed. Test key accepted only
from 127.0.0.1 inside the container (uvicorn without `--proxy-headers`).
Tested in the Docker image (826 MB) run with the README's flags: 27 tests
pass (incl. a real DOCX conversion); DOCX/ODT/XLSX/ODS with HU/DE text
convert in under 1 s; 401 without token and for the test key from the
host; healthy; no leftover files. The real run found two things, both
fixed: `docker cp` fails on a `--read-only` container (README now pipes
the file in with `docker exec -i`), and LibreOffice turned random bytes
named `.docx` into a garbage PDF (now 400: file must start with the ZIP,
OLE2 or RTF signature for its extension). Sent
`Forditva-conversion-server-2026-10-16.zip` and
`Forditva-conversion-server-package-2026-10-16.docx`. **Still to do:** a
real App Check token from the dev phone once deployed; then the app side
(path, size check per route, error kinds).

---

## 6. Token Server API contract and TTS function (Alex, 2026-10-16)

**Alex sent:** `API.md` (Token Server v3 at
`https://forditva-api.wir-in-ungarn.hu`, not live yet: register, sync,
redeem, recover, recovery/rotate, health; 200 WIU welcome; gift codes
500/1000/2000/5000; sync at start and on foreground if 8 h or older;
integers only; balance may go below 0; no server spend cap in v1; old
prepaid codes not migrated) and `TTS-FUNCTION.md` (callable function
`synthesizeSpeech` in forditva-151, App Check enforced, Node 22,
europe-west1, design only). Copies in `~/Downloads`.

**Checked in the code:** read-aloud uses 8 WaveNet voices (de-DE-B,
hu-HU-A, en-US-D, fr-FR-F, es-ES-B, it-IT-D, nl-NL-F, ru-RU-A), MP3, no
length limit (long photo/PDF results can exceed Google's 5,000 bytes and
fail silently), cache only on the Text page, 0.0016 WIU per character.
`TokenBalance` keeps an integer balance plus a fraction, clamps at 0, and
has no lifetime spent total yet; the wallet needs one.

**Answers to Alex:** round the exact lifetime total down (yes); voices
as above, allow-list exactly these; MP3; validate 5,000 bytes only (app
splits longer texts at sentence ends); way 2, service account, no key;
the app caches, no server cache; europe-west1 is fine; debug token for
the dev phone, testers via Play internal/closed testing. Debug token
follows after a debug run on the phone; Apple Team ID waits for Markus's
iOS answer (Xcode project has `75Y9R496R9`, unconfirmed); Play signing
SHA-256 after the first upload (needs Play admin access). Asked: go-live
date of the server, who writes and deploys the function.

**Debug token (2026-10-16):** generated on the dev phone (Xiaomi) with a
debug build signed with the sideload key; Firebase initialised without
errors. Sent to Alex privately (value not stored in the repo; it lets any
debug build pass App Check, revoke it in the console if it leaks). Side
effect: `flutter run` found a different signer on the installed build 70
and uninstalled it by itself, so the phone's local test data (WIU,
history) is gone; the debug build is installed now.

---

## 7. Status and timeline for Markus (2026-10-16)

**Markus asked:** current status, what is missing, when Android is done.

**Play Console:** Markus has one and removed Kayode; we are not admin yet.

**Sent:** `docs/reviews/2026-10-16-android-status-timeline.md`, Word copy
`Forditva-Android-status-and-timeline-2026-10-16.docx`, together with
the conversion server package. Plan: 19-23 Oct Gemini via AI Logic, UI
changes, first internal-test upload; 26-30 Oct wallet and recovery
screens, voice input via Gemini, conversion server; 2-6 Nov read-aloud
function, keys removed, test build via internal testing; closed test from
about 9 Nov; release first half of December. **Revised the same day**
(the user: finish our part over the weekend): closed test runs in
parallel with the remaining work, starting about 21-23 Oct once we have
Play access and 12 testers; weekend: AI Logic, key cleanup, read-aloud
split, UI changes, store/privacy/form drafts; 19-21 Oct wallet against
the contract and first upload; test ends about 4-6 Nov; release about
mid-November (organisation account: possibly early November). Asked him for: Play admin access,
account type, 12+ testers, store texts and graphics, privacy policy
update, form answers to confirm, five open decisions.

---

## 8. Go-live by Wednesday 21 Oct

**Markus asked (19 Oct):** the time plan, since the wir-in-ungarn.hu
changes go live by Wednesday at the latest and Forditva should be on Play,
ideally also on the App Store.

**Answer sent:** a public Play release by Wednesday is not possible: a new
personal account needs a 14-day closed test with 12+ testers plus review,
and we are still not admin. If he grants admin today, the first build goes
to a closed test the next day, installable from Play via an opt-in link;
public release about mid-November. App Store after Android (iOS Firebase
app, Apple team confirmation and Apple review missing). Asked again for
admin access, account type and 12 tester emails.

---

## 9. Read-aloud through Alex's Firebase function

**Alex asked (19 Oct):** switch read-aloud from the Google key to his
callable function `synthesizeSpeech` (europe-west1, App Check), use 8
voices (4 renamed: de-B to H, hu-A to B, es-B to E, it-D to F), follow his
error rules, test from the dev phone, then remove the old key.

**Changed:** `lib/services/gemini_tts_service.dart` calls the function
(`cloud_functions` package, 40 s timeout). Texts over 5,000 UTF-8 bytes are
split at sentence ends and the MP3 parts joined. unavailable and
deadline-exceeded are retried once; `google_rejected` splits the text in
two and retries; resource-exhausted and permission-denied show their own
message. WIU is charged once, after every part succeeded, on the
`characters` the function reports. Read-aloud errors now show a message on
every page (`showTtsError` in `lib/widgets/error_dialog.dart`); before, the
Conversation speakers failed silently and stayed in the "playing" state.
Tests: `test/tts_split_test.dart`.

**Tested on the Xiaomi (debug build):** HU 4.7 s (first call, cold start),
HU 0.6 s, DE (Wavenet-H) 0.6 s, ES (Wavenet-E) 0.95 s. No error codes seen.
IT and the error paths are not tested live.

**Not done:** the old key can't be removed yet. Read-aloud used
`GOOGLE_STT_KEY`, the same key voice input still uses, so revoking it
would break voice input until that moves too.

**Open (Markus):** German and Hungarian for two new messages, English ships
until then: "Read-aloud is not available at the moment." and "Read-aloud
is busy right now. Please try again in a minute."

---

## 10. Voice input through Gemini (both mics)

**Why:** the phone's recognizer played its start sound ("pling") on every
restart after a pause, returned no punctuation and has no Hungarian on some
phones (Xiaomi); Cloud STT gave no Hungarian punctuation, stopped at 60 s
and needed an API key in the app.

**Changed:** `lib/services/gemini_speech_service.dart` (new). Both the
Conversation mic (`recording_modal.dart`) and the edit-panel mic
(`edit_recording_modal.dart`) record 16 kHz mono WAV and Gemini Flash-Lite
transcribes it through Firebase AI Logic (no key). Limit 5 minutes per
recording. Audio that never reached speech level is not sent, because on
near-silence Gemini invents a sentence. The edit panel now transcribes in
the panel's language (it always used German or Hungarian before) and a
double tap on stop no longer sends the audio twice. `speech_to_text` and
`google_speech_to_text_service.dart` are removed; the app no longer reads
`GOOGLE_STT_KEY`. Not billed in WIU (Markus decides).

**Tested on the Xiaomi:** Conversation 4.0 s for 24 s of audio, edit panel
3.5 s, infinity mode 3.1 s; punctuation correct, no pling.

**Cost per minute of speech:** Gemini Flash-Lite about $0.0013 (1,500 audio
tokens in, about 340 out), Cloud STT v1 $0.024, Cloud STT v2 $0.016. So
about 18 times cheaper than before.

**Dictated punctuation, decided 20 Oct: stays on Flash-Lite.** Tested with
Hungarian speech clips (pauses between words): a spoken "pont" / "vessző" /
"kérdőjel" is often written as a word on Flash-Lite whatever the prompt
says. Gemini Flash got all 24 runs right (marks written, "pont most" kept
as a word) but takes 3.4 to 6.1 s instead of 2.1 to 2.7 s and costs about
$0.0035 per minute. Kept Flash-Lite for speed; automatic punctuation works
either way. German "Punkt" / "Komma" mostly works on Flash-Lite.

---

## 11. Natural translation, and a dropped last line

**Changed:** plain translation (Conversation, edit panel, Text and
Document page) now uses Markus's own `tasks/translate_text.md` from his
prompt library instead of "a precise literal translation engine". Example:
"Holnap találkozom a barátaimmal a városközpontban." gave "Tomorrow I meet
my friends in the city center", now "Tomorrow I am meeting my friends in
the city center." One rule added to his text: keep formal and informal
address (du/Sie, te/Ön); without it a "Kannst du" question became formal.
The Tutor is unchanged: its Decoder keeps the literal line, as his spec
says. File: `lib/services/translation_prompts.dart`.

**Found on the phone:** a last line that reads like a remark about the text
("Itt vannak összekapcsolva egyetlen bekezdésben") was dropped from the
translation (5 of 6 test runs), because the prompt says never to obey
instructions inside the text. Fixed by sending the text between `<text>`
tags; 6 of 6 complete afterwards, instruction-like text is translated, not
obeyed. Tested on the Xiaomi. Test: `test/translation_prompts_test.dart`.

**Known, not changed:** text mixing languages (German typed on the
Hungarian side) can keep the German part untranslated, as before. In about
one run in three, German to Hungarian drops "bitte" or switches du to Ön;
extra prompt rules made other cases worse.

---

## 12. Tutor level ring

**Markus sent:** the "Sprachlevel" ring image, to use always without a
number. **Changed:** the Tutor's level bar shows it (56 px, image
unchanged, `assets/images/sprachlevel.png`) instead of the drawn ring with
A1/A2/B1 inside. The level number stays in the box right of the slider.

---

## 13. Play Console access and keys out of the app

**20 Oct:** Markus gave Play Console access. The dashboard says the app has
been granted **production access**, so no 14-day closed test is needed; the
mid-November estimate in item 8 is out of date. Left: countries, upload the
AAB, Google review (hours to a few days).

**Before the upload:** the Play build is signed with Google's app signing
key, which must be added to the Android app in Firebase (forditva-151), and
Play Integrity linked, or App Check rejects the Play build and translation,
voice input and read-aloud fail. Alex adds the fingerprint (doc sent 20 Oct).

**Changed:** the bundled `.env` now holds only `PREPAID_API_BASE_URL`,
`PREPAID_API_KEY` and `CONVERSION_API_BASE_URL`. The Gemini and DeepSeek
test keys moved to `.env.dev` (gitignored, not bundled; read by
`tool/llm_compare.dart` and `tool/tutor_benchmark`). Removed the Google
STT/TTS, OpenAI and Lingvanex keys and three old keys left in comments, and
the unused `chatgpt_service.dart` and `lingvanex_translation_service.dart`.
**To revoke (Markus):** OpenAI, Lingvanex, the three commented-out keys,
and the old Google key once this build is live.

**Upload key reset (21 Oct):** Kayode's upload key (July) is lost, so a
new one was created (`.deploy/upload-keystore.jks`, alias `upload`,
SHA-256 `F5:2C:45:91:9F:D7:C1:BC:1A:2B:C4:A8:7C:83:86:09:F8:B7:B1:36:6E:4D:26:90:9B:98:D0:AE:34:E6:7C:CE`).
"Request reset" was greyed out for the developer account; Markus
requested it. Google: valid from **23 Oct 2026, 20:03**; no upload before
then. Play app signing key (Google's, for Firebase App Check): SHA-256
`03:FD:44:FE:8D:EE:0D:02:D2:54:BB:B1:26:EA:94:4D:50:9D:5E:7D:39:8E:08:23:D6:9E:18:BC:FF:D5:42:E9`,
SHA-1 `1C:D8:EE:15:F5:A0:BE:32:F6:D5:F7:16:45:28:80:C0:F9:E5:62:5D`.

**Alex (doc, 20 Oct):** read-aloud results, old key can go after release,
DeepSeek function request (`deepseek-flash`, no `response_format`, token
counts back), app signing fingerprint on upload day.

---

## 14. DeepSeek through Alex's function (test builds only)

**Alex (21 Oct):** callable `deepseekChat` deployed (europe-west1, App
Check, fresh key from Markus). Contract:
`~/Downloads/API-deepseekChat-for-Abdulsalam-21oct.md`.

**Changed:** `lib/services/ai/deepseek_firebase.dart` (new) calls it;
`ai_router.dart` tries DeepSeek first for translation and the Tutor
(`deepseekTasks`) and falls back to the job's Gemini model on any error,
charging WIU only for the model that answered. permission-denied (balance
empty or switched off) turns DeepSeek off until the app restarts. Texts
over 100,000 UTF-8 bytes go straight to Gemini; output capped at 3,700
tokens; 70 s timeout. Only on in builds made with
`--dart-define=DEEPSEEK=true`, until Markus confirms the privacy policy
update. The old in-app DeepSeek key path is gone.

**Tested on the Xiaomi (21 Oct):** 6 calls, all answered by DeepSeek, no
fallback: translation 4.9 s (first call, cold start), Tutor 1.6 to 2.6 s
(137 to 3,440 tokens in, 53 to 237 out); a repeated Tutor request hit
DeepSeek's cache (768 of 913 input tokens cached).

**Side effect:** with DeepSeek, Tutor thinking is always off, so "Answer
now" saves almost nothing; an abandoned Tutor request still finishes and is
charged (a Firebase call cannot be cancelled).

---

## 15. Untranslated German and Hungarian texts

**Reported (21 Oct):** the Tutor's loading text "A good answer takes a
moment..." stays English in German and Hungarian. 16 German and 21
Hungarian texts fall back to English. Markus's rule for translations:
always the informal version (du, not Sie; te in Hungarian). **Shipped
21 Oct** (user's decision) with the texts below, sent to Markus for
feedback; corrections go in afterwards. Changed from the first draft:
"{language} használata" became "{language} nyelv használata".

| Key | English | German (proposal) | Hungarian (proposal) |
|---|---|---|---|
| tutorThinking | A good answer takes a moment... | Eine gute Antwort braucht einen Moment ... | Egy jó válaszhoz kell egy kis idő ... |
| tutorAnswerNow | Answer now | Jetzt antworten | Válasz most |
| tutorChooseSentences | Choose sentences | (has: Sätze auswählen) | Mondatok kiválasztása |
| tutorCharCount | {count} / {max} characters | (has) | {count} / {max} karakter |
| tutorConsecutiveOnly | only consecutive sentences | (has) | csak egymást követő mondatok |
| tutorApplySelection | Apply selection | (has) | Kijelölés alkalmazása |
| tutorLevel | Language level | (has: Sprachlevel) | Nyelvi szint |
| readAloudUnavailable | Read-aloud is not available at the moment. | Vorlesen ist gerade nicht verfügbar. | A felolvasás most nem érhető el. |
| readAloudBusy | Read-aloud is busy right now. Please try again in a minute. | Vorlesen ist gerade ausgelastet. Bitte versuche es in einer Minute noch einmal. | A felolvasás most túlterhelt. Kérlek, próbáld újra egy perc múlva. |
| languageMismatchBody | This text is in {detected}, not {selected}. | Dieser Text ist auf {detected}, nicht auf {selected}. | Ez a szöveg {detected}, nem {selected}. |
| languageNotFoundBody | No {selected} text was found. Please check the source language. | Kein Text auf {selected} gefunden. Bitte prüfe die Ausgangssprache. | Nem található {selected} szöveg. Kérlek, ellenőrizd a forrásnyelvet. |
| languageMismatchUse | Use {language} | {language} verwenden | {language} használata |
| languageNameHu ... It | Hungarian, German, English, Dutch, French, Spanish, Russian, Italian | Ungarisch, Deutsch, Englisch, Niederländisch, Französisch, Spanisch, Russisch, Italienisch | magyar, német, angol, holland, francia, spanyol, orosz, olasz |
| swipeToDeleteTip | Tip: swipe an entry to the left to delete it. | Tipp: Wische einen Eintrag nach links, um ihn zu löschen. | Tipp: húzz egy bejegyzést balra a törléséhez. |

Grammar caveat: the language names are inserted into sentences. German
"auf Ungarisch" works; Hungarian needs an adjective form for "Ez a szöveg
magyar" but a case ending elsewhere, so Markus should check the two
sentences with a name inside.

---

## 16. All AI in the EU (Markus, via Alex, 22 Oct)

**Decision:** every AI call must run in the EU. DeepSeek stays off in
every build, test builds too; translation and the Tutor stay on Gemini.
Gemini moves from the Gemini Developer API (globally pooled, no location)
to the Vertex AI Gemini API with an EU location; App Check stays on. Alex
enables Vertex AI in the Firebase project and picks the location.
Read-aloud moves to Google's EU endpoint on his server, no app change.

**Done (22 Oct):** DeepSeek removed from the app:
`deepseek_firebase.dart` and its test deleted, `runAiTask` is Gemini-only.
No CI or Play build ever set `DEEPSEEK=true`; only the local debug build
on the Xiaomi called it, and it gets replaced. The DeepSeek price entries
and REST path stay for the comparison tools in `tool/` only. Code is in
git (`747e1ef`) if Markus ever wants it back.

**Sent to Alex:** our models. `gemini-3.5-flash-lite` for translation,
Text-page explain and voice input; `gemini-3.8-flash` for the Tutor,
language check, photos and PDFs. No Live API.

**Next, when Alex gives the location:** `gemini_firebase.dart` switches
from `FirebaseAI.googleAI()` to `FirebaseAI.agentPlatform(location: ...)`
(firebase_ai 4.0 defaults that to "global", so the location must be set),
and `ai_models.dart` pins the versioned model names instead of the
`-latest` aliases. Then a full test on the Xiaomi before the AAB.

**Also found while testing (22 Oct):**
- Edit panel: tapping the check on an empty field sent the empty text to
  Gemini, whose empty answer crashed the Firebase SDK parser ("Unhandled
  format for Content: {}") and left the panel spinning. Now an empty field
  clears both panels with no AI call, history entry or read-aloud
  (`edit_recording_modal.dart`, `_playSoundWithOpenAI` skips empty text),
  and any failed translation in the panel shows the error popup and keeps
  the text.
- Read-aloud slow: 2.9 to 19.3 s per call today (77 to 339 bytes), no
  errors; 0.6 to 0.95 s on 20 Oct. Phone network fine (65 ms to the
  function host), Gemini voice input normal (4.4 s). Asked Alex whether
  `synthesizeSpeech` changed. Update 23 Oct: it was the MTN mobile
  connection; on office Wi-Fi read-aloud takes 0.55 to 2.0 s.

**Done (23 Oct, +73):** Alex enabled Vertex AI and chose "eu".
`gemini_firebase.dart` calls `FirebaseAI.agentPlatform(location: 'eu')`;
`ai_models.dart` pins `gemini-3.5-flash-lite` and `gemini-3.8-flash`.
Every feature answered 200 through
`firebasevertexai.googleapis.com/v1beta/projects/forditva-151/locations/eu/...`
on the Xiaomi: language check, translation, voice input (3.2 s), Tutor
(Decoder 22.9 s with 1,401 thinking tokens; Learning focus with "Answer
now" 14.5 s), photo (6.0 s check + 7.8 s translation). PDF not tested.
Alex moved read-aloud to Google's EU endpoint and deleted `deepseekChat`.
Also in +73:
- Language check runs with thinking off: it took ~4.5 s before every
  translation, now 0 to 32 thinking tokens.
- Text page: the result card's icons use the input card's spacing
  (Markus).
- Edit panel shows the app's grid loader instead of the blue spinner.

Occasional slow calls on "eu" even on good Wi-Fi: Flash-Lite 18.7 s for
289 tokens in / 11 out, 3.8 Flash 28.2 s for 123 in / 1 out. Watch for
it; "europe-west4" is Alex's fallback location.

**Release day for Alex:** send him the Play app signing SHA-256 (Play
Console > App integrity) after the first upload, and link the Play
Integrity API to the Cloud project. He enforces App Check for AI Logic
before 2 Nov; after that, sideloaded APKs lose AI, so testers install from
Play.

Play app signing keys (Play Console > App signing, 23 Oct):
- In use: `03:FD:44:FE:8D:EE:0D:02:D2:54:BB:B1:26:EA:94:4D:50:9D:5E:7D:39:8E:08:23:D6:9E:18:BC:FF:D5:42:E9`
- Previous (first used 27 Jul 2026, marked "Quantum-ready (beta)"):
  `F5:2C:45:91:9F:D7:C1:BC:1A:2B:C4:A8:7C:83:86:09:F8:B7:B1:36:6E:4D:26:90:9B:98:D0:AE:34:E6:7C:CE`
Upload key (ours): `1F:51:...:8F:75`. Alex registers both signing keys in
Firebase; Play signs new installs with the one in use.

**Capacity problem on "eu" (23 Oct, 15:30 to 15:50 WAT, from the Mac):**
3.5 Flash-Lite 10/10 OK (avg 1.5 s); 3.8 Flash 1/10 OK (7 timeouts at
90 s, 2x 429 "Resource exhausted"); 3.5 Flash also timed out. Every
regional EU location (europe-west1/3/4/8/9, north1, central2,
southwest1) answers 404 "not found or your project does not have access"
for every model, even gemini-2.5-flash, so there is no EU fallback for
our project today. The language check runs on 3.8 Flash before every
translation, so every translation waits on it. Evening rerun (21:44 WAT): 3.8 Flash 10/10, avg 2.0 s, so it is
peak-hour capacity, not a permanent fault. Sent to Alex as a docx
(`Forditva-open-points-for-Alex-2026-10-23.docx`).

**Done in +75 (23 Oct):**
- Language check back on Flash-Lite: 32/34 short samples right (only "OK"
  read as EN), against 29/31 for 3.8 Flash with thinking off; about 1 s.
- Photo/PDF/Office translation with thinking off (the 4-row XLSX: 2,472
  thinking tokens and 33 s before, none after). "Ask about this document"
  keeps thinking.
- Conversation page: leaving the page while read-aloud loads no longer
  throws "setState() called after dispose()".

---

## 17. Conversion server live (Andy, 23 Oct)

Andy deployed `conversion-service/` at
`https://convert.wir-in-ungarn.hu/convert/to-pdf` (HTTPS, port 8000 closed,
401 without a token, 429 after 3 quick requests, 413 over 16 MiB, 27 tests
passed). The app now uses that URL by default (it was blank in `.env`, so
the Office formats were hidden on the Image page) and the new path
`/convert/to-pdf`, and waits 100 s instead of 60 s, since the server allows
LibreOffice 90 s.

Tested from the Mac with an App Check token from the phone's debug secret
(23 Oct): DOCX 3.3 s, XLSX 3.0 s, ODT 2.0 s, ODS 2.3 s, all 200 with
correct Hungarian and German accents in the PDF. The fifth request (DOC)
in the same burst got 429, as Andy's limit intends; a minute later DOC
converted in 2.3 s. No token and a bad token both got 401; an HTML file
renamed to .docx got 400 ("File content does not match its format").
Still to do: the same from the app on the phone.

---

## Update for Markus (draft, send when the round is done)

1. **API keys off the phone.** (Rewrite once Alex's contract arrives.)
   Alex is building the key proxy on your Token Server 3.0 package; I
   sent him every Google call the app makes and how the app counts WIU.
   Once his contract is ready I switch the app over and remove the Google
   keys from it.
