# forditva: App Store listing (draft, 12 Nov 2026)

Status: **draft**. 15 Nov: "200 credits" removed from the descriptions (Markus: people think they must pay); the new lines reuse his start-dialog wording. English is ours; German and Hungarian need Markus's
correction before they go live (du/te form, like the app). Nothing here is in
App Store Connect yet except what the "Already set" section lists.

## Already set in App Store Connect (12 Nov)
- App name `forditva` (DE), subtitle DE "Übersetzen, sprechen, lernen"
- Category: Reference (primary), Education (secondary)
- Store version **1.0.4**, release **manual** (was "automatic"; set via API)
- Build 89 processed (VALID); TestFlight: Linus (internal), Rita (external,
  waiting for beta review)

## Still needed from Markus / Alex
- **Support URL**: Apple needs a web page, not an email. Suggestion: a short
  forditva page or the contact page on wir-in-ungarn.hu with
  team@wir-in-ungarn.hu on it.
- **Privacy policy** `https://wir-in-ungarn.hu/datenschutz-forditva/`:
  must cover the iPhone app, Google Gemini (Vertex AI, EU), read-aloud,
  the conversion server and the device identifier for credits.
- ~~Review gift code~~: received from Alex 15 Nov, three codes with 1000
  credits each, stored in `.deploy/apple/review-gift-codes.txt` (not in git).
  One goes into the review notes; the others are spares for a second review.
- Corrections of the DE and HU texts below.

---

## Subtitle (max 30)
- DE: Übersetzen, sprechen, lernen
- EN: Translate, speak, learn
- HU: Fordíts, beszélj, tanulj

## Promotional text (max 170)
- DE: Ungarisch verstehen statt nur übersetzen: Texte, Gespräche, Fotos und Dokumente, mit einem Tutor, der dir Satzbau und Grammatik erklärt.
- EN: Understand Hungarian, not just translate it: texts, conversations, photos and documents, with a tutor that explains sentence structure and grammar.
- HU: Ne csak fordíts, értsd is: szövegek, beszélgetések, fotók és dokumentumok, egy tutorral, aki elmagyarázza a mondatszerkezetet és a nyelvtant.

## Keywords (max 100, comma separated)
- DE: ungarisch,deutsch,übersetzer,sprachen lernen,grammatik,dolmetscher,ungarn,wörterbuch,foto,dokument
- EN: hungarian,german,translator,learn hungarian,grammar,interpreter,hungary,dictionary,photo,document
- HU: német,magyar,fordító,nyelvtanulás,nyelvtan,tolmács,szótár,fotó,dokumentum,beszélgetés

## Description (max 4000)

### DE
forditva ist mehr als ein Übersetzer. Die App hilft dir, dich auf Ungarisch und Deutsch zu verständigen und Ungarisch wirklich zu verstehen.

TEXT ÜBERSETZEN
Schreib oder diktier einen Text und erhalte sofort die Übersetzung zwischen Ungarisch und Deutsch, auf Wunsch auch mit Englisch und weiteren Sprachen. Lass dir das Ergebnis vorlesen.

GESPRÄCHSMODUS
Zwei Personen, zwei Sprachen, ein Handy: Jeder spricht in seiner Sprache, forditva übersetzt und liest vor.

FOTOS UND DOKUMENTE
Fotografiere einen Brief, ein Schild oder eine Speisekarte oder lade ein Bild, ein PDF oder eine Word-, Excel- oder OpenOffice-Datei. forditva übersetzt den Inhalt und beantwortet Fragen dazu.

UNGARISCH LERNEN MIT DEM TUTOR
Der Tutor erklärt dir jeden Satz in drei Modi:
- Verstehen: was der Satz bedeutet und wie er gemeint ist
- Dekodieren: Wort für Wort, mit Endungen und Satzbau
- Lernfokus: die wichtigsten Grammatikpunkte zum Üben

OHNE ANMELDUNG
Kein Konto, kein Login. Du kannst forditva kostenlos nutzen.

KI UND DATENSCHUTZ
forditva nutzt ausschließlich Google Gemini (in der EU). Bevor Inhalte an die KI gehen, fragt die App nach deiner Zustimmung; du kannst sie in den Einstellungen jederzeit widerrufen. Übersetzungen werden nicht mit deiner Person verknüpft.

forditva ist ein gemeinnütziges Projekt der Community Wir in Ungarn (wir-in-ungarn.hu).

### EN
forditva is more than a translator. It helps you communicate in Hungarian and German and actually understand Hungarian.

TRANSLATE TEXT
Type or dictate a text and get the translation between Hungarian and German right away, with English and other languages too. Have the result read aloud.

CONVERSATION MODE
Two people, two languages, one phone: each speaks their own language, forditva translates and reads it aloud.

PHOTOS AND DOCUMENTS
Take a photo of a letter, a sign or a menu, or open an image, a PDF or a Word, Excel or OpenOffice file. forditva translates the content and answers your questions about it.

LEARN HUNGARIAN WITH THE TUTOR
The tutor explains every sentence in three modes:
- Understanding: what the sentence means and how it is meant
- Decoding: word by word, with endings and sentence structure
- Learning Focus: the key grammar points to practise

NO SIGN-UP
No account, no login. You can use forditva for free.

AI AND PRIVACY
forditva uses Google Gemini only (in the EU). Before any content goes to the AI, the app asks for your consent, and you can withdraw it in the settings at any time. Translations are not linked to your identity.

forditva is a non-profit project of the Wir in Ungarn community (wir-in-ungarn.hu).

### HU
A forditva több, mint egy fordító. Segít megértetni magad magyarul és németül, és tényleg megérteni a magyar nyelvet.

SZÖVEGFORDÍTÁS
Írj vagy diktálj be egy szöveget, és azonnal megkapod a fordítást magyar és német között, angolul és más nyelveken is. Az eredményt fel is olvastathatod.

BESZÉLGETÉS MÓD
Két ember, két nyelv, egy telefon: mindenki a saját nyelvén beszél, a forditva lefordítja és felolvassa.

FOTÓK ÉS DOKUMENTUMOK
Fotózz le egy levelet, táblát vagy étlapot, vagy nyiss meg egy képet, PDF-et, Word-, Excel- vagy OpenOffice-fájlt. A forditva lefordítja a tartalmat, és válaszol a kérdéseidre.

MAGYARTANULÁS A TUTORRAL
A tutor minden mondatot háromféleképpen magyaráz el:
- Megértés: mit jelent a mondat, és hogyan értendő
- Dekódolás: szóról szóra, ragokkal és mondatszerkezettel
- Tanulási fókusz: a legfontosabb nyelvtani pontok gyakorláshoz

REGISZTRÁCIÓ NÉLKÜL
Nincs fiók, nincs bejelentkezés. A forditvát ingyenesen használhatod.

MI ÉS ADATVÉDELEM
A forditva kizárólag a Google Gemini-t használja (az EU-ban). Mielőtt bármilyen tartalom a mesterséges intelligenciához kerül, az alkalmazás a hozzájárulásodat kéri, amit a beállításokban bármikor visszavonhatsz. A fordításokat nem kapcsoljuk a személyedhez.

A forditva a Wir in Ungarn közösség (wir-in-ungarn.hu) nonprofit projektje.

---

## Other version fields
- Copyright: © 2026 Markus Messemer
- Marketing URL: optional, e.g. https://wir-in-ungarn.hu
- Price: free; availability: all countries

## App Review information
- Sign-in required: **no**
- Contact: Markus Messemer, team@wir-in-ungarn.hu (phone: the user decides)
- Notes (EN), Markus's text of 16 Nov with the Settings path corrected
  (the top-up field is in Settings, not behind the credits display). The
  real code is in App Store Connect only; codes live in
  `.deploy/apple/review-gift-codes.txt`.

  > forditva does not require an account or login. On first launch, the app
  > requests consent for the content processing required by its AI features,
  > which use Google Gemini. AI processing remains disabled until consent is
  > given. Consent can be withdrawn in Settings.
  >
  > New users receive 200 free credits to get started: tap "Start for free"
  > in the dialog that follows the consent page. To test topping up, tap the
  > menu icon at the left of the bottom bar to open Settings, enter this
  > top-up code in the "Add credits" field and tap the green button next to
  > it: **[CODE] (1000 credits)**.
  >
  > The app is free to download worldwide. During the first six months,
  > top-up codes are distributed free of charge. This release does not sell
  > credits or link to a purchase page. Camera, photo library and microphone
  > access support the photo, document and speech features.

## Age rating
Entered via API on 16 Nov: every content question None; every capability
No (ads, age assurance, gambling, health, loot boxes, chat, parental
controls, web access, user-generated content, social media). Earlier
proposal:
All content categories (violence, sexual content, profanity, drugs, gambling,
horror, medical, etc.): **None**. Unrestricted web access: **No**.
User-generated content shared with other users: **No** (nothing is shared
between users). Messaging/chat between users: **No**. If the form asks about
AI-generated content or a chatbot: **Yes**, the Tutor and translation answer
free-text input. Expected result: 4+ (Apple may set a higher age because of
the AI answers; that is fine).

## App Privacy (browser only, the API can't set it), verified 16 Nov
Tracking: **No**. Purpose for every type: **App Functionality** only.

| Data type | Linked to user | Why |
|---|---|---|
| User Content > Other User Content | No | texts and documents go to Gemini; Google may keep prompts for abuse detection |
| User Content > Audio Data | No | voice input is transcribed by Gemini |
| User Content > Photos or Videos | No | photos and images go to Gemini |
| Identifiers > Device ID | **Yes** | token server keeps a hash of it, tied to the credits wallet |
| Identifiers > User ID | **Yes** | the credits wallet is an assigned ID (with its backup code) |
| Usage Data > Other Usage Data | **Yes** | ledger of credits granted, spent and redeemed per wallet |

Gemini requests carry no device ID (only an App Check token), so content is
not linked. Not collected: contact info, location, health, financial,
browsing, search history, usage data, diagnostics (no analytics, crash or ad
SDK). Matches `ios/Runner/PrivacyInfo.xcprivacy` (Device ID set to linked on
16 Nov; ships with the next build).

## Privacy facts (16 Nov, from the code, Alex and Andy)
- **Gemini** (translation, Tutor, photos, documents, speech recognition):
  Firebase AI Logic on Vertex AI, location `eu`, project forditva-151,
  protected by App Check. Request/response logging off, data caching off
  (since 16 Nov). Google may log prompts only to detect abuse (Google Cloud
  terms 4.3) and does not train on the data.
- **Speech recognition**: the app records audio itself and Gemini
  transcribes it (same path as above). No Apple or Google speech service.
- **Read-aloud**: Alex's Firebase function `synthesizeSpeech`
  (europe-west1) calls `eu-texttospeech.googleapis.com`. The text is never
  logged; one log line per call with voice name, character count and
  status, kept 30 days in Cloud Logging.
- **Document conversion**: Andy's server at Contabo, Germany. Each file
  goes into a temporary folder that is deleted right after the PDF is sent
  back (or right away on an error). The app log has only file type, sizes
  and duration, no file name or content. No analytics or error-tracking
  service; the only outbound call fetches Google's public App Check keys.
  Andy (16 Nov): Nginx Proxy Manager access log (time, IP, method, URL,
  status, size, user agent, referrer; no body), rotated, files cover about
  two weeks, no fixed period yet. Docker logs: json-file, 3 × 10 MB,
  size-based.
- **Credits wallet** (token server): a hash of the device ID
  (identifierForVendor on iPhone, Android ID on Android) linked to a
  wallet with granted and spent totals, hashes of the access credential
  and recovery code, a wrong-code counter, created and last-sync dates;
  redemptions (code hash, wallet, date) and a balance ledger. No texts,
  names, e-mail or IP addresses in the database. Access log with IP, path
  and status: deleted nightly (at most 24 h). Reverse proxy log with IP:
  about 4 weeks.
- **No** analytics, crash reporting, advertising or tracking SDKs.

## Screenshots
Required: 6.9" iPhone, 1320 × 2868 (portrait), 3 to 10 per language. Plan:
text translation, conversation mode, photo/document, Tutor (one per mode),
welcome/consent page. From the release build, no private data.
