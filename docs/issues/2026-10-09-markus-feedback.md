# Markus's feedback round, 2026-10-09

One entry per item Markus raised. Each entry records what he reported, what
we found, what we changed, and every decision made along the way, so the
"Update for Markus" section at the bottom can be sent to him once the whole
round is done. Plain English; DE/HU copy is never written here (standing
rule), only proposed and sent to Markus for correction.

Status key: `open`, `confirm` (ask Markus first), `done`, `done, untested`.

| # | Where | Issue | Status |
|---|---|---|---|
| 1 | Voice input (cloud recognition) | Dictated sentences come back as one block with no periods | done, EN verified on device 2026-10-09; DE/HU for Markus to test |
| 2 | History, Favorites, Tutor history | Icons should sit in the top-right corner, not vertically centered | done, all three verified on device 2026-10-09 |
| 3 | Edit panel / Document | Recording waveform too small; no way to choose where dictated text goes | done, verified on device 2026-10-09 |
| 4 | All pages | One language-mismatch panel everywhere; Image page should not re-read a document to find out the language is wrong | done, verified on device 2026-10-09; DE/HU copy needed from Markus |
| 5 | Image | Upload hint (icons + text) too big | done, verified on device 2026-10-09; DE/HU text wording to confirm with Markus |
| 6 | Navigation | Rename the third page to Datei / Fájl / File | done, to verify on device |
| 7 | WIU balance | Low-balance warning should start at 50, not 200 | done, to verify on device |
| 8 | Tutor | New Tutor: three tabs (Understanding / Decoding / Learning Focus), level slider, sentence picker (consecutive, max 300 characters) | built, to test on device; some DE/HU copy needed from Markus |
| 9 | Tutor | Tabs, bulb and background not matching the mockup | done, to verify on device |
| 10 | Bottom bar | Outline uneven (right side); page name should be as large as the longest word allows | done, verified on device 2026-10-09 |
| 11 | Text page | Top card has more space around its text than the bottom card; top icons should be left-aligned | done, verified on device 2026-10-09 |
| 12 | All pages | Changing the third language in Settings should switch the pages to it | done, verified on device 2026-10-09 |
| 13 | History, Tutor history | First-use tip: swipe left to delete | done, to verify on device; DE/HU copy needed from Markus |
| C | Billing | Found while testing: Gemini "thinking" tokens were not billed | done (tests) |
| D | Code | Code cleanup before the test build: 76 analyzer warnings down to 2 | done, to smoke-test on device |
| A | Conversation | Found while testing: error in the log when leaving the page while audio plays | done, verified on device 2026-10-09 |
| B | Image | Found while testing: language row broken when the third language is Dutch/French/Spanish/Russian/Italian | done, to verify on device |

---

## 1. Voice input lost its punctuation

**Markus reported:** since the switch to cloud recognition, punctuation is
gone. He dictated three sentences, each ending with a period, and got one
block. His AI suggested enabling `enable_automatic_punctuation` in the
`RecognitionConfig`.

**What we found** (`lib/services/google_speech_to_text_service.dart`):

- The cloud request never asked for punctuation. Markus's suggestion was
  right.
- A second bug in the same place: Google splits longer recordings into
  several pieces, and the app kept only the first piece. Longer dictations
  silently lost everything after it.
- We tested Google's cloud recognizer directly with German, English and
  Hungarian sample sentences. With punctuation switched on, English and
  German come back punctuated (and a spoken "Punkt" becomes "."). Hungarian
  comes back with no punctuation at all, on every recognizer model Google
  offers for our API key. Google's newer recognizer (v2, "Chirp") does not
  accept API keys, only server credentials, so it is not usable from the app
  without a server.

**What we changed:**

- Cloud recognition now asks for automatic punctuation (all languages).
- All pieces of a longer recording are joined, nothing is dropped.
- Hungarian only: after recognition, the text goes through Gemini with a
  strict instruction to add punctuation and capital letters and change no
  words. The app checks the words are identical before using the result; if
  Gemini changed any word, fails, or takes longer than 8 seconds, the
  unpunctuated text is used instead. Adds about 2 seconds to Hungarian
  dictation.
- The on-device recognizer (used whenever the phone itself supports the
  language, as on Markus's Samsung) is unchanged.

**Decisions:**

- *Hungarian punctuation via Gemini, not charged in WIU* (decided 2026-10-09).
  It costs a fraction of a cent per dictation, so billing it would mostly
  add noise to the balance. Alternatives considered: charge WIU for it, or
  leave Hungarian unpunctuated.
- *No "spoken punctuation" setting.* Google's option for it did nothing
  useful in tests (in English "period" stayed a word), and German "Punkt"
  already works without it.

**Testing:** live API checks for EN/DE/HU done; unit test for the
word-check guard (`test/google_speech_to_text_service_test.dart`). On a
phone: English verified 2026-10-09 on the Xiaomi (cloud path, periods shown), no app errors in the log. German and Hungarian to be tested by Markus.

---

## 2. History, Favorites and Tutor history: icons in the top-right corner

**Markus reported:** a before/after mockup of the History list. The Tutor
bulb and the star sat vertically centered on the right of each card. He
wants them in the top-right corner.

**What we found** (`lib/history.dart`, `lib/favorite.dart`): both cards put
the icons in a row next to the text, so they were centered and took a full
column of width from both texts.

**What we changed:** the icons now sit in the top-right corner of each card.
Following the mockup, only the first (green) text stops short of the icons;
the translation below uses the full card width. Tapping the bulb, the star,
and swiping to delete work as before.

**Tutor history** (`lib/learning_list.dart`): it had the bulb on the
*left* and no star; the bulb is only a marker there (tapping the card opens
the entry). It now sits in the top-right corner too, with the sentence
stopping short of it and the explanation below at full width.

**Decisions:**

- *Tutor history included* (2026-10-09): first left out because the request
  named History and Favorites, then included on request so all three lists
  match.

**Side finding (not fixed yet):** a German to English favorite showed the
Tutor bulb, which should only appear when Hungarian is involved. That entry
was probably saved with the wrong language. To investigate.

**Testing:** History, Favorites and Tutor history verified on the Xiaomi
2026-10-09 (icons placed, taps and swipe-to-delete work), no runtime errors.

---

## 3. Edit panel: bigger waveform, and dictating into the middle of a text

**Markus reported** (screen recording `2026-10-09 12.04.12.mp4`, 2:35, Document
page):

- *0:05-0:58:* the recording waveform is "really too small"; put it
  "above somewhere, separately", so there is enough space for the buttons.
- *1:07-2:30:* he wants to add a sentence between two existing sentences.
  Tapping the text only offers copy, and the mic always puts the dictation
  at the end. Going through the pencil, tapping between the sentences and
  then the mic worked, but he is "not happy" with it and asked for a better
  idea.

**What we found:**

- `lib/widgets/edit_recording_modal.dart`: while recording, the waveform
  shared the bottom button row with six buttons, so on his phone it had
  room for about one bar.
- `lib/document/document_translation_page.dart`: tapping the text was
  *meant* to open the edit panel (Markus's 2026-07-11 request), but the
  read-only text box swallowed the tap, so it only selected text for
  copying. The mic always opens the panel with the cursor at the end.

**What we changed:**

- While recording, the waveform now shows as a full-width band just above
  the button row; the text area makes room for it. The recording discard
  and stop buttons sit centred in the row. This is the shared edit panel, so
  the Conversation page gets the same change.
- On the Document page, tapping into the text opens the edit panel with the
  cursor exactly where you tapped. Tap the mic there and the sentence is
  inserted at that spot. Long-press still selects text for copying.

**Decisions** (2026-10-09):

- *Waveform band above the buttons*, not at the top of the panel: it stays
  next to the recording controls. Alternative considered: band at the top.
- *Tap on the text = edit at that spot*, rather than the mic silently
  remembering the last tap position (no visible cursor, easy to insert in
  the wrong place).
- The view-mode mic still appends at the end; tapping into the text first
  is the way to insert in the middle.

**Testing:** to verify on device.

---

## 4. One language-mismatch panel for the whole app

**Markus reported** (screen recording `telegram-cloud-document-2-...mp4`,
2:50, "something we should handle a bit more globally"):

- *0:00-0:53, Document page:* the text is German. Switching the source
  language to Hungarian just translated it again "as Hungarian". The app
  should say the text is not Hungarian instead.
- *1:00-2:46, Image page:* a Hungarian PDF that also contains German.
  Switching the source to English re-read the whole document (costing WIU
  again) only to say "In dieser Datei wurde kein EN-Text gefunden".
  "EN-Text" should be a real language name, the message type should
  change, and the app should know the document's languages from the first
  analysis without analyzing again.

**What we found:** four separate mismatch dialogs, each built and worded
differently, three of them showing codes or nothing instead of language
names:

1. Document page, green check: German/Hungarian text hard-coded in the
   source instead of the translation files ("The detected language is DE").
2. Image page after analysis: "Detected language is DE but your selected
   input is HU" (codes).
3. Image page, nothing found: "kein EN-Text gefunden" (the one in the video;
   only shown after a full, paid re-read).
4. Edit panel (Conversation + Document): generic "Wrong language", no
   detected language, no way to switch.

None ran when the source language was changed with text present, which is
the case in the video.

**What we changed:**

- One shared panel (`lib/widgets/language_mismatch_dialog.dart`) replaces
  all four. It reads "This text is in German, not Hungarian." with
  [Use German] and [Cancel], using real language names. Use switches the
  source language (swapping with the target if needed) and translates;
  Cancel changes nothing. When the language can't be told, it says "No
  Hungarian text was found. Please check the source language." with OK.
- Document page: changing the source flag with text present now checks the
  text first; the green check uses the same panel.
- Conversation page: the edit panel uses the same panel and, on [Use ...],
  updates the page's languages. (The Conversation flags change the target
  of the other side, so they cannot cause a mismatch.)
- Image page: the first analysis now also reports which languages the
  document contains (a few extra words in the same request, no extra
  upload). Switching the source flag, or swapping, to a language the
  document doesn't contain shows the panel instantly, with no re-read and
  no WIU. Switching to a language it does contain (German in his bilingual
  PDF) re-reads as before. If a result was found in the chosen language,
  it is always kept.

**Decisions** (2026-10-09):

- *Panel offers the detected language*, [Use X] / [Cancel], rather than a
  plain OK. Cancel leaves the source language as it was, so the flag never
  stays on a wrong language (in the video it still showed EN afterwards).
- *Image languages come from the first analysis*, not from a separate check
  on each switch: a separate check would upload the whole document again
  every time (about half the cost of an analysis); this way it costs only a
  few output words once.
- *All three pages* get the panel.
- *A found result is never thrown away* because of the language list; the
  list only decides when Gemini found no text in the chosen language, or
  for the instant check before a re-read.

**Tested:** live Gemini test on a bilingual HU/DE PDF: Hungarian and German
sources return their text plus "HU, DE"; English returns nothing plus
"HU, DE" (panel offers Hungarian); explain mode unchanged. Unit tests for
the language-line parser (`test/gemini_image_languages_test.dart`). On
device (Xiaomi, 2026-10-09): Document source-flag check, Image instant
check, and edit panel all verified.

**Follow-up (2026-10-09):** the panel was first built with Flutter's
default dialog look (the pinkish box from Markus's video). Restyled to
match the app's own modals: white card, rounded corners, Roboto Condensed,
bold centred title, red [Cancel] and green [Use ...] pill buttons (green
[OK] when there is nothing to suggest).

**Needs Markus (German and Hungarian copy):** English ships now; German and
Hungarian show the English text until he sends his wording. Proposed
drafts for him to correct:

| Key | English | German (draft) | Hungarian (draft) |
|---|---|---|---|
| title (existing) | Wrong Language | Falsche Sprache | Rossz nyelv |
| languageMismatchBody | This text is in {detected}, not {selected}. | Dieser Text ist auf {detected}, nicht auf {selected}. | Ez a szöveg {detected}, nem {selected}. |
| languageNotFoundBody | No {selected} text was found. Please check the source language. | Es wurde kein Text auf {selected} gefunden. Bitte überprüfe die Ausgangssprache. | Nem található {selected} szöveg. Kérjük, ellenőrizd a forrásnyelvet. |
| languageMismatchUse | Use {language} | {language} verwenden | {language} használata |
| language names | Hungarian, German, English, Dutch, French, Spanish, Russian, Italian | Ungarisch, Deutsch, Englisch, Niederländisch, Französisch, Spanisch, Russisch, Italienisch | magyar, német, angol, holland, francia, spanyol, orosz, olasz |

(Hungarian grammar note for Markus: the sentence form depends on how the
language name is inflected, e.g. "magyar nyelvű"; he may prefer a different
sentence shape.)

---

## 5. Image page: smaller upload hint

**Markus reported:** a before/after mockup of the empty Image page: "Please
reduce the size of the hint."

**What we changed** (`lib/image_page.dart`): measured his mockup against the
current screen; everything is about 75% of its old size, so icons 72 -> 54,
text 26 -> 20, gap between icons 28 -> 21, gap above the text 16 -> 12.

**Found along the way:** his German screenshot reads "Bild oder Dokument
hochladen (PDF, Word, Excel, OpenDocument oder Textdatei)". When the Office
formats were hidden (until the conversion server exists), only the English
text was changed to "(PDF or text file)"; German and Hungarian still promise
Word, Excel and OpenDocument, which the file picker no longer accepts.

**Decision:** not changed yet (standing rule: no self-written German or
Hungarian). Proposed to Markus, only removing words from his own text:

- German: "Bild oder Dokument hochladen (PDF oder Textdatei)"
- Hungarian: "Kép vagy dokumentum feltöltése (PDF vagy szövegfájl)"

**Testing:** verified on the Xiaomi 2026-10-09 (screenshot matches the
mockup's proportions).

---

## 6. Third page renamed to "Datei / Fájl / File"

**Markus asked:** name the third page (Image/Document) "Datei" (DE),
"Fájl" (HU), "File" (EN).

**What we changed:** the page name string `imageMode` in all three
translation files: EN "Image/Document" -> "File", DE "Bild" -> "Datei",
HU "Kép" -> "Fájl". This also settles the open DE/HU naming question from
the 2026-09-29 video (issue 3 there). German and Hungarian are Markus's
own wording.

**Testing:** to verify on device.

---

## 7. Low-balance warning from 50 WIU

**Markus asked:** "Please change the warning level to 50."

**What we changed** (`lib/services/token_balance.dart`): the "Your WIU
balance is getting low" warning now appears below 50 WIU instead of 200.
This also fixes issue A from the 2026-09-29 video: with the old 200 limit
above the 100 WIU welcome grant, every new user saw the warning from the
start.

**Testing:** to verify on device.

---

## 8. New Tutor

**Markus sent:** three handoff files (now in `docs/tutor-handoff/`: `FORDITVA_Tutor_Method_1_Handoff.md`,
`FORDITVA_Decoder_Implementation_Handoff.md`,
`FORDITVA_Tutor_Mode_3_Handoff.md`), a Tutor page mockup with three tabs
and a level slider, the tab names, and a sentence-picker mockup: "if the
text has more than one sentence ... choose sentences with up to 300
digits ... only fields which are following each other".

Tab names (his wording): Verstehen / Megértés / Understanding,
Dekodieren / Dekódolás / Decoding, Lernfokus / Tanulási fókusz /
Learning Focus.

**Decisions** (2026-10-09):

- *Tabs by order:* Understanding = Method 1 (level-dependent, slider shown
  there as in the mockup), Decoding = Decoder, Learning Focus = Mode 3.
- *Hungarian UI:* the prompts cannot explain in Hungarian, so the Tutor
  explains in the page's other language (e.g. German on a HU-DE page),
  falling back to German.
- *Sentence picker:* one AI request splits the text into sentences and
  translates each (shown under the sentence, as in the mockup).
- *A single sentence over 300 characters* can be chosen on its own (never
  combined), otherwise it could never be explained.
- *Speed vs accuracy (Markus, voice note):* "the stable way": the model
  thinks before answering (Understanding ~13 s, Learning Focus ~17 s,
  Decoder 36 s to 2 min), with an "Answer now" button as in Gemini. In the
  app that button asks for the fast version (no thinking, ~4 s, small
  slips such as "Arbeitᴾˡ" for "Arbeitenᴾˡ") and shows whichever answer
  arrives first.
- *Existing translations stay as they are* (Markus, voice note: "the
  translations which Kayode implemented were good ... use the same model").
- Prompts are generated verbatim from his handoff files
  (`lib/tutor/tutor_prompts.dart`); all three were tested live on his test
  sentence and return valid JSON in the required structure.

**What we built:**

- A Tutor page in the app (bottom bar title "Tutor"), replacing the four
  old Tutor popups (Conversation, Document, Image/File, History/Favorites).
  The bulb on every page, the bulb in History and Favorites, and entries in
  the Tutor history all open it.
- Three tabs as in the mockup: the active tab shows icon and name, the
  others only their icon. Each tab's result is kept, so switching back and
  forth costs nothing; Understanding is kept per level.
- Level slider (01-99) under Understanding, as in the mockup; it is the same
  level as in Settings. Releasing it at a new level asks for a new
  explanation.
- Sentence picker when the text has more than one sentence: Hungarian
  sentence with its translation, "{n} / 300 characters", only neighbouring
  sentences, deselect only from either end; sentences that can't be added
  are faded.
- While the accurate answer is on its way: "A good answer takes a
  moment...", and after 3 seconds an "Answer now" button.
- Results are saved in the Tutor history and reopen without a new request.
- Validation and one retry with the handoffs' retry sentence when the AI
  returns invalid JSON. Unit tests for the picker rules
  (`test/sentence_selection_test.dart`).
- Icons for the three tabs are standard icons for now (speech bubble,
  network, target, as in the mockup). If Markus has his own icon files,
  they can be swapped in.

**Needs Markus (copy):**

| Key | English | German | Hungarian |
|---|---|---|---|
| tutorChooseSentences | Choose sentences | Sätze auswählen (from mockup) | needed |
| tutorCharCount | {count} / {max} characters | {count} / {max} Zeichen (from mockup) | needed |
| tutorConsecutiveOnly | only consecutive sentences | nur aufeinanderfolgende Sätze (from mockup) | needed |
| tutorApplySelection | Apply selection | Auswahl übernehmen (from mockup) | needed |
| tutorLevel | Language level | Sprachlevel (from mockup) | needed |
| tutorThinking | A good answer takes a moment... | needed | needed |
| tutorAnswerNow | Answer now | needed | needed |

**Testing:** to do on device.

---

## 9. Tutor page matched to the mockup

**Reported (testing):** the active tab's green did not fill the whole tab,
the bulb at the top left and the page background did not match Markus's
mockup.

**What we changed** (`lib/tutor/tutor_page.dart`): the active tab is a
green pill filling the full height of the white tab bar from its edge, the
other tabs are icons separated by a thin line, as in the mockup; the bulb
is larger; the page has the app's light tile background behind the white
content card.

**Testing:** to verify on device.

---

## 10. Bottom bar: even outline, larger page name

**Markus reported** (screenshot with his Photoshop fix): "The outline, also
on right side, is not drawn nicely" and "the fontsize of this roboto
condensed word need to be the maximum which you can reach for the longest
word ... try with conversation and beszélgetés".

**What we found** (`lib/main.dart`): the black outline was painted under
the clipped coloured sections, whose edges covered it unevenly. The page
name size was chosen so every page name fits on ONE line, so the two-word
names ("Tanulási lista", "Learning List") kept it small for every page.

**What we changed:** the outline is now painted on top of the sections,
with a soft shadow like his Photoshop version. The name size is now the
largest at which every single word fits ("Conversation", "Beszélgetés");
two-word names wrap onto two lines at that same size, so all names stay one
size (his 2026-07-11 rule).

**Testing:** verified on the Xiaomi 2026-10-09.

---

## 11. Text page: same spacing in both cards

**Reported (testing):** the top card had more space around its text than
the bottom card, and its icons were centred instead of left-aligned like
the bottom card's.

**What we changed** (`lib/document/document_translation_page.dart`): the
top card uses the bottom card's inset (10 on all sides, no extra inner
padding) and its icon row starts at the same left position as the bottom
card's; its distance from the bottom edge is unchanged.

**Testing:** verified on the Xiaomi 2026-10-09 (text and first icons line
up in both cards).

---

## 12. Third language from Settings shown right away

**Markus reported:** when the third language is changed in Settings, the
app should switch to it.

**What we found:** the pages only offered the new third language when
cycling the flags; a language already on screen was never updated. With an
English app, the pages also always started on English, whatever third
language was chosen (`getInitialLangPair`).

**What we changed** (`lib/services/third_language_pref.dart` and the three
pages): any language other than Hungarian and German shown on a page is
replaced by the chosen third language, when the page opens and the moment
it is changed in Settings. If the target side changes, the existing text is
translated into the new language (on the File page from the text already
read, without reading the document again).

**Testing:** verified on the Xiaomi 2026-10-09 (Spanish chosen in
Settings; Conversation switched from EN to ES).

---

## 13. First-use tip: swipe left to delete

**Requested (2026-10-09):** the first time a user opens the history lists,
show a tip that swiping left deletes an entry.

**What we changed** (`lib/widgets/swipe_delete_tip.dart`, used by
`lib/history.dart` and `lib/learning_list.dart`): a small tip card above
the list, with a swipe icon and a close button. It disappears for good,
separately per list, once the user closes it or deletes an entry by
swiping.

**Decision:** History and Tutor history only. Favorites has no swipe
action; removing a favorite is done by tapping its star, which stays as is.

**Needs Markus (copy):** English "Tip: swipe an entry to the left to delete
it." German and Hungarian show English until he sends his wording.

**Testing:** to verify on device.

---

## C. Found while testing: AI "thinking" was not billed

While testing the Decoder: Google charges the model's hidden thinking at
the output rate, but the app billed only the visible answer, so
thinking-heavy requests (Tutor, and any other call where the model thinks)
cost users a fraction of the real price. **Decision (Markus, voice note,
2026-10-09):** bill it from the user's credits ("it all remains within a
few fractions of a cent"). Fixed in `lib/services/gemini_cost.dart`
(`billableOutputTokens`), used by text translation, image analysis and the
Tutor; unit tests added.

---

## D. Code cleanup before the test build

**Why:** `flutter analyze` reported 76 issues, mostly leftovers from earlier
versions (unused code, missing safety checks, outdated library calls).
Cleaned up without changing what the app does, as one separate commit.

**What we changed:**

- Deleted six files nothing in the app uses (they are not even compiled
  into it): the old `RecordingPage.dart`, the old `settings_page.dart`,
  `help_support_page.dart`, `license_credit_page.dart`,
  `services/OpenAiTtsService.dart`, `widgets/SmartScrollableText.dart`.
  They remain in git history.
- Removed unused functions, fields and variables in the live pages (all
  plain calculations, nothing with side effects). One unused variable,
  `_isAudioPlaying` on the Conversation page, is kept with a note: its
  updates also refresh the page, so removing them could change behaviour.
- Added "is the page still open?" checks in 8 places that used the screen
  after waiting for a network or file call; they only matter when the user
  has already left the page.
- Small mechanical fixes: `print` -> `debugPrint`, braces, type signatures,
  and four drop-in replacements for outdated Flutter calls.

**Decisions** (2026-10-09):

- *Delete the six unused files* rather than fix warnings in code nobody
  runs. Note for Markus: a help/support page and a licence page existed but
  were never linked from Settings; they can be restored if he wants them.
- *Leave the 2 speech-recognition warnings*: replacing them touches the
  voice input we just stabilised; best done in a round with voice testing
  on several phones.

**Testing:** analyzer 76 -> 2 issues (the two above), unit tests unchanged
(all pass except the default counter template, which failed before), app
restarted on the Xiaomi; smoke test to do.

---

## A. Found while testing: audio error when leaving the Conversation page

**Not reported by Markus**; found in the app log while testing item 2.

**What we found** (`lib/textpage.dart`): when you leave the Conversation page
while a translation is being read aloud, the app closes that page and stops
its audio players. A stopped player reports "stopped" one last time, and the
page's three audio listeners then tried to update a page that no longer
existed (`setState() called after dispose()`). Users saw nothing (the error
only went to the log, audio stopped as expected), and the skipped follow-up
step only clears a loading indicator on the closed page.

**What we changed:** each of the three audio listeners now checks that the
page is still open before updating it, and unsubscribes if not.

**Decision:** include it in this round (decided 2026-10-09): small, low
risk, and the only Forditva error seen in the log during testing.

**Testing:** verified on the Xiaomi 2026-10-09: switched pages mid-playback,
no error in the log.

## B. Found while testing: Image page broken for a non-English third language

**Not reported by Markus**; seen on the test phone, whose third language
(Settings) is Dutch.

**What we found** (`lib/image_page.dart`): the Image page draws each
language name from a picture (`EN-EN.png`, `DE-DE.png`, `HU-HU.png`). Its
list also pointed at `NL-NL.png`, `FR-FR.png`, `ES-ES.png`, `RU-RU.png` and
`IT-IT.png`, which were never added, so choosing any of those as the third
language replaced the language row with an "Unable to load asset" error box.
The Document and Conversation pages show the code as text and were fine.

**What we changed:** HU, DE and EN keep their label pictures; the other
five languages show their code as text next to the flag, like the Document
page.

**Decision:** fix it in this round, since any user with one of those five
third languages hits it on the Image page.

**Testing:** to verify on device.

---

## Update for Markus (draft, send when the round is done)

1. **Punctuation in voice input.** You were right, the cloud recognition was
   missing the automatic punctuation setting. It is on now, and periods,
   commas and capital letters are back for German and English. While fixing
   it we found that longer dictations lost everything after the first part;
   that is fixed too. Google's cloud recognition cannot punctuate Hungarian
   at all, so for Hungarian the app now lets Gemini add only the punctuation
   afterwards (it checks that no word was changed). This adds about 2
   seconds and costs no WIU. Please test German and Hungarian dictation with
   a few sentences.
2. **History, Favorites and Tutor history icons.** The bulb and the star
   now sit in the top-right corner of each entry, as in your mockup, on all
   three lists. The first text line
   makes room for them, and the translation below uses the full width.
3. **Found while testing.** Leaving the Conversation page while a
   translation was being read aloud caused a hidden error in the app's log.
   You would not have noticed anything, but it is fixed now.
4. **Recording waveform and inserting dictation.** While recording, the
   waveform now has its own full-width strip above the buttons. On the
   Document page, tapping into the text opens the edit mode with the cursor
   exactly where you tapped; tap the microphone and your sentence is
   inserted there. Long-press still selects text for copying.
5. **Wrong source language, handled the same everywhere.** There is now one
   message for the whole app: "This text is in German, not Hungarian." with
   [Use German] or [Cancel], with real language names instead of codes. It
   appears when you change the source language on the Document page, when
   you confirm text, and in the edit panel. On the Image page, the first
   analysis now also notes which languages the document contains, so
   switching to a language that isn't in it is caught immediately, without
   reading the document again and without costing WIU. Please send your
   German and Hungarian wording for the new texts (drafts below in this
   file).

6. **Found while testing.** If the third language in Settings was Dutch,
   French, Spanish, Russian or Italian, the Image page's language row broke
   (an error box instead of the language name), because label pictures only
   existed for German, Hungarian and English. Those five languages now show
   their code as text next to the flag.
7. **Smaller upload hint.** The icons and text on the empty Image page are
   now about 75% of their old size, as in your mockup. One question: the
   German and Hungarian text still lists Word, Excel and OpenDocument, which
   the app does not accept until the conversion server is running. May we
   shorten it to "Bild oder Dokument hochladen (PDF oder Textdatei)" and
   "Kép vagy dokumentum feltöltése (PDF vagy szövegfájl)"?
8. **Page name.** The third page is now called "Datei" / "Fájl" / "File".
9. **Low-balance warning.** It now appears below 50 WIU instead of 200, so
   new users with the 100 WIU welcome grant no longer see it right away.
10. **WIU billing includes the AI's thinking.** As you decided, the hidden
    "thinking" Google charges for is now included in the WIU price (with
    your +30% margin), for every AI feature.
11. **New Tutor.** The Tutor is now its own page with your three tabs
    (Understanding, Decoding, Learning Focus), the level slider and the
    sentence picker (only neighbouring sentences, up to 300 characters). It
    answers accurately by default, with an "Answer now" button for a quick
    answer, as you suggested. Saved explanations reopen from the Tutor
    history without a new request. Please send the German and Hungarian
    for the texts listed in this file.
12. **Tutor design.** The tabs, bulb and background now follow your mockup.
13. **Bottom bar.** The outline is drawn evenly all around, with a soft
    shadow, as in your Photoshop fix. The page name is as large as the
    longest word allows; two-word names wrap onto two lines at the same
    size.
14. **Text page.** Both cards now have the same space around the text, and
    the icons in the top card are left-aligned like in the bottom card.
15. **Third language.** Changing the third language in Settings now
    switches the pages to it immediately, including the language a page
    starts with.
16. **Code cleanup.** Before this test build we removed unused old code
    and added safety checks, without changing how the app works. Note: an
    old help/support page and a licence page existed in the code but were
    never reachable from Settings; we removed them. Tell us if you want
    either one in the app.
17. **Swipe tip.** History and Tutor history now show a one-time tip that
    swiping an entry to the left deletes it. Please send the German and
    Hungarian for "Tip: swipe an entry to the left to delete it."
