# Markus's feedback round, 2026-10-25

Markus tested 1.0.2 (76) from Play internal testing. One entry per item:
what he asked for, what we found and changed, and the decisions, so the
"Update for Markus" section at the bottom can be sent once the round is
done.

| # | Where | Issue | Status |
|---|---|---|---|
| 1 | History, Favorites, Learning list | Bulb and favourite icons should match | done in 1.0.3 (77) |
| 2 | File page | Pick other pages of the same PDF without loading it again | done in 1.0.3 (77) |
| 3 | Text page (all pages) | Stop square thinner than the other icons | done in 1.0.3 (77) |
| 4 | Text page (all pages) | Read-aloud: 5 to 6 s with no reaction to the tap | done in 1.0.3 (77) |
| 5 | File page | PDF translation gives only "the most important words", not the whole text | done in 1.0.3 (77) |
| 6 | File page | Full-screen view of a document result (the user's idea) | done in 1.0.3 (77) |
| 7 | All pages | Tips for the icons (the user's idea) | proposal for Markus, not built |

## 1. Bulb and favourite icons

**Markus:** "Can the light bulb and favourite icon have matching designs?"

**Found:** the entries in History, Favorites and the Learning list used
the old `assets/images/bulb.png` (bold, with rays) and Flutter's built-in
star, not Markus's icon set. The bottom bar already used his set.

**Changed:** both are now his line icons, `b_lightbulb.png` and
`b_favorit.png`. His set has no filled star, so a favourite shows the star
in gold and a normal entry in grey; the shape stays his. The Tutor page
header still has the old bulb (56 px); not changed, ask Markus.

## 2. Pick other pages of the same PDF

**Markus (video 21.28.40):** "I need to know where I can click to define
another" page selection; he had to load the file again.

**Decision (the user):** tap the loaded PDF.

**Changed:** tapping the PDF icon or file name in the upper panel reopens
the page picker with the pages translated last time ticked, opened on the
first of them. Under the file name a line shows the pages, e.g. "Pages
4-11". New pages are translated right away; the same pages or Cancel change
nothing. Office files converted to PDF work the same way.

**New text (drafts, please correct):** EN "Page 3" / "Pages 4-11", DE
"Seite 3" / "Seiten 4-11", HU "Oldal: 3" / "Oldalak: 4-11".

**Tested on the emulator with this booklet:** pick pages 2 and 3, the
panel shows "Pages 2-3"; tap the PDF, the picker opens on page 2 with
pages 2 and 3 ticked; untick 2, OK, the panel shows "Page 3". The
translation itself could not run there (the emulator has no registered
App Check token); test it on the phone from Play.

## 3. Stop icon

**Markus (voice note):** "the stroke width of the square icon, which is the
pause icon, is not the same as all the other icons."

**Decision (the user):** use Markus's pause icon; tapping stops as before.

**Changed:** while reading aloud, the speaker turns into his
`b_pause.png` / `w_pause.png` on the Text page, both Conversation cards and
the File page. The old `w_stop.png` square is no longer used there.

## 4. Read-aloud feedback

**Markus (voice note):** "if the text is really long, it takes 5 to 6
seconds until the audio starts… when I click on it, I need some sort of
reaction… For this, I need some ideas."

**Options considered:** the app's grid loader in place of the speaker;
switching straight to the pause icon; a dimmed speaker.

**Decision (the user):** the grid loader.

**Changed:** after the tap, the speaker shows the app's grid loader (the
same one as on the Image page and in the edit panel) until the audio
starts, then the pause icon, then the speaker again. On all three pages.
The File page had no read-aloud state at all before (no stop either); it
now works like the others.

## 5. PDF translation gave only key words

**Markus (video 21.28.40, `hcb_01_0.pdf`, pages 4 to 11, Hungarian to
English):** "it is giving me a few words translated. But it should give me
the whole text… this is only the most important words translated."

**Found:** the booklet is English with Hungarian dish names. The
translation prompt said "extract only Hungarian text segments", so Gemini
returned exactly the Hungarian dish names: 17 segments, 24 words, out of
about 2,640 words on those pages. Reproduced from the Mac with the app's
prompt. Thinking was not the cause: English to Hungarian with the old prompt
covered the whole text with thinking off and on.

**Changed:** the prompt now asks for all text in reading order (headings,
paragraphs, list items, table cells), one segment per paragraph, every
segment translated into the target language whatever its language, text
already in the target language copied unchanged, nothing shortened or left
out. The same booklet: 73 segments, 2,636 of about 2,640 words. A
Hungarian invoice into German: every line, date converted, numbers kept.
In "original + translation" view, a segment that is already in the target
language shows once, not twice.

**Cost:** translating everything costs more than translating a few names:
the 8 booklet pages used about 7,700 output tokens, roughly 11 WIU.

## 6. Full-screen view on the File page (the user's idea)

**Found:** the expand icon opened the landscape view built for the
Conversation page (one sentence, sideways, 48 px), and fed it the whole
result joined into one block.

**Changed:** on the File page it now opens an upright full-screen reader
that shows the result exactly like the panel (paragraph by paragraph,
original and translation as set by the toggle, explanations with their
structure), scrollable, with pinch to zoom and a close icon. The
Conversation and Text pages keep the landscape view.

## 7. Tips for the icons (proposal)

Not built. Suggestion for Markus: long-press tooltips on every icon now,
and later a short tour per page on first start (with "Skip", and "Show tips
again" in the menu). Draft English texts, for his wording and German and
Hungarian:

- [Ax] Translate / Explain the document
- [文A] Original and translation / translation only
- Speaker: Read aloud
- ?: Ask a question about this document
- Copy, Share, Full screen
- PDF icon: Choose other pages
- Bulb: Tutor
- Star: Favourite

## The two translate icons on the File page

For reference (asked 25 Oct): [Ax] switches between translation (line by
line) and explanation (a summary in the target language; then the "?" for
questions appears). [文A] appears only in translation mode and switches
between original + translation and translation only.

## Update for Markus (draft, send when the round is done)

Hi Markus, version 1.0.3 is on Play internal testing with your points from
25 Oct:

1. History, Favorites and Learning list now use your bulb and star icons.
   A favourite shows the star in gold.
2. PDF pages: tap the loaded PDF (icon or file name) to pick other pages;
   the pages translated last time are ticked, and the panel shows which
   pages you translated.
3. While reading aloud, the speaker turns into your pause icon (tap
   stops), on all pages.
4. After you tap the speaker, the grid loader shows until the audio starts.
5. PDF translation: the app translated only the Hungarian parts of your
   recipe booklet, because it is mostly English. It now translates the
   whole text, and text already in the target language stays as it is.
   This costs more WIU for long documents (about 11 WIU for 8 dense pages).
6. The expand icon on the File page opens a full-screen page you can
   scroll and zoom, instead of the sideways view.

A suggestion: tips for the icons (long-press help on each icon, later a
short tour). If you like it, please send me the wording in German and
Hungarian. My English draft: Translate / Explain the document; Original
and translation / translation only; Read aloud; Ask a question about this
document; Copy; Share; Full screen; Choose other pages; Tutor; Favourite.
