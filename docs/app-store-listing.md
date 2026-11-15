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
- Notes (EN):

  > forditva needs no account. On first launch the app shows a welcome page
  > that explains the AI processing (Google Gemini via Firebase, EU region)
  > and asks for consent; AI features stay off until the user agrees, and the
  > consent can be withdrawn in Settings. Every new install gets 200 free
  > credits. To test topping up, open the wallet (credits display) and redeem
  > this gift code: **[CODE FROM ALEX, 500+ credits]**. Credits are free
  > during this release; the app sells nothing and links to no purchase.
  > Camera, photo library and microphone are used only for translating
  > photos, documents and speech.

## Age rating (proposed answers)
All content categories (violence, sexual content, profanity, drugs, gambling,
horror, medical, etc.): **None**. Unrestricted web access: **No**.
User-generated content shared with other users: **No** (nothing is shared
between users). Messaging/chat between users: **No**. If the form asks about
AI-generated content or a chatbot: **Yes**, the Tutor and translation answer
free-text input. Expected result: 4+ (Apple may set a higher age because of
the AI answers; that is fine).

## App Privacy (browser only, the API can't set it)
Tracking: **No**. Data types, all "not linked to the user", purpose **App
Functionality** only, not used for tracking:
- **User Content > Other User Content**: texts and documents sent for
  translation (Google Gemini, conversion server)
- **User Content > Audio Data**: voice input (Gemini) and read-aloud
- **User Content > Photos or Videos**: photos/images sent for translation
- **Identifiers > Device ID**: identifier-for-vendor, used for the credit
  wallet and app security (Firebase App Check)

Not collected: contact info, location, health, financial, browsing, search
history, usage data, diagnostics (no analytics or crash SDK in the app).
This matches `ios/Runner/PrivacyInfo.xcprivacy`.

## Screenshots
Required: 6.9" iPhone, 1320 × 2868 (portrait), 3 to 10 per language. Plan:
text translation, conversation mode, photo/document, Tutor (one per mode),
welcome/consent page. From the release build, no private data.
