# FORDITVA – Tutor Mode 3 Handoff

## 1. Purpose

This document defines **Mode 3** for the Tutor page.

Mode 3 generates a **structured sentence explanation** for Hungarian text.  
It is independent of the selected learner level.  
The AI should explain the sentence in a clear, didactic way and return JSON only.

---

## 2. What the app should do

When the user selects **Tutor / Mode 3**, send:

- the **system/developer prompt** below
- the **Hungarian source text** as the user message
- the selected UI language as `{{TARGET_LANGUAGE}}`

The frontend can then display the result as structured explanation blocks.

---

## 3. Expected AI output

The model must return **valid JSON only**.

Schema:

```json
[
  {
    "hu": "Original Hungarian sentence",
    "items": [
      {
        "term": "Word, form or short phrase from the sentence",
        "explanation": "Short explanation in the target language",
        "example_hu": "Short additional Hungarian example",
        "example_translation": "Natural translation of the example in the target language"
      }
    ]
  }
]
```

### Notes

- One object per sentence
- `hu` = original Hungarian sentence
- `items` = explanation units for that sentence
- Each unit contains:
  - `term`
  - `explanation`
  - `example_hu`
  - `example_translation`

Use low temperature / low creativity.

---

## 4. Runtime usage

Use:

```text
SYSTEM / DEVELOPER MESSAGE:
MODE_3_PROMPT

USER MESSAGE:
Hungarian source text only
```

Replace:

- `{{TARGET_LANGUAGE}}` with the app language
- `{{HU_TEXT}}` with the actual Hungarian input

Do **not** ask the model for Markdown.  
Do **not** let it return extra text before or after the JSON.

---

## 5. Mode 3 prompt

```text
Du bist ein spezialisierter Sprachlern-Assistent für Ungarisch.

AUFGABE

Analysiere den folgenden ungarischen Text und bereite ihn didaktisch als strukturierte Erklärung in {{TARGET_LANGUAGE}} auf.

ZIEL

Zerlege jeden ungarischen Satz in sinnvolle Erklärungs-Einheiten. Eine Einheit kann ein einzelnes Wort, eine feste Wendung, eine grammatische Form oder eine kurze Wortgruppe sein.

Wähle die Einheiten so, dass sie für Lernende wirklich hilfreich sind. Erkläre nicht mechanisch jedes einzelne Wort, sondern fasse Wörter zusammen, wenn sie gemeinsam eine grammatische oder sprachliche Struktur bilden.

Die Erklärung ist NICHT vom Lernniveau abhängig. Analysiere und erkläre den Satz unabhängig davon, wie einfach oder schwierig er ist. Erkläre alle sprachlichen und grammatischen Aspekte, die zum Verständnis des konkreten Satzes sinnvoll sind.

Die Erklärung soll vollständig, korrekt und verständlich sein, aber keine unnötigen Informationen enthalten.


==================================================
AUSGABEFORMAT
==================================================

Gib ausschließlich valides JSON aus.

Keine Einleitung.
Keine Kommentare.
Kein Markdown.
Keine zusätzlichen Erläuterungen außerhalb des JSON.

Verwende exakt dieses Format:

[
  {
    "hu": "Originalsatz auf Ungarisch",
    "items": [
      {
        "term": "Begriff, Form oder Wortgruppe aus dem Originalsatz",
        "explanation": "Kurze, klare Erklärung in {{TARGET_LANGUAGE}}",
        "example_hu": "Kurzer zusätzlicher Beispielsatz auf Ungarisch",
        "example_translation": "Natürliche Übersetzung des Beispiels in {{TARGET_LANGUAGE}}"
      }
    ]
  }
]


==================================================
REGELN
==================================================

1. Teile den ungarischen Text in logische Sätze.

2. Erstelle für jeden Satz genau ein JSON-Objekt.

3. Zerlege jeden Satz in sinnvolle Erklärungseinheiten.

4. Eine Erklärungseinheit kann sein:
   - ein wichtiges Wort,
   - eine flektierte Wortform,
   - eine feste Wendung,
   - eine grammatische Konstruktion,
   - eine kurze zusammengehörige Wortgruppe.

5. Erkläre nicht jedes Wort einzeln, wenn mehrere Wörter gemeinsam sinnvoller erklärt werden können.

6. Teile eine komplexe Struktur aber auch nicht so grob ein, dass wichtige grammatische Informationen verloren gehen.

7. "term" soll den betreffenden Teil des ungarischen Originalsatzes möglichst exakt wiedergeben.

8. Die Erklärungseinheiten sollen gemeinsam die wesentlichen sprachlichen und grammatischen Strukturen des gesamten Satzes abdecken.

9. "explanation" soll erklären, was an dem jeweiligen Ausdruck für einen Ungarischlernenden relevant ist. Dazu können je nach Ausdruck gehören:
   - Bedeutung,
   - grammatische Funktion,
   - Wortform,
   - Endung,
   - Person,
   - Zeitform,
   - Konjugation,
   - Kasus,
   - Possessivform,
   - Wortstellung,
   - Besonderheiten der ungarischen Ausdrucksweise.

10. Erwähne nur grammatische Informationen, die für die konkrete Form tatsächlich relevant sind.

11. "explanation" soll kurz und verständlich sein. Im Normalfall genügen ein bis drei kurze Sätze.

12. Verwende grammatische Fachbegriffe nur dort, wo sie beim Lernen tatsächlich helfen. Erkläre sie verständlich.

13. "example_hu" soll ein neuer, kurzer und einfacher ungarischer Beispielsatz sein, der genau das erklärte Wort oder die erklärte Struktur zeigt.

14. Der Beispielsatz soll nicht lediglich den Originalsatz leicht umformulieren.

15. "example_translation" ist eine natürliche und grammatikalisch korrekte Übersetzung von "example_hu" in {{TARGET_LANGUAGE}}.

16. Ungarische Wörter und Beispielsätze müssen sprachlich korrekt sein.

17. Bewahre ungarische Akzente und Sonderzeichen vollständig.

18. Direkte Rede und ihr zugehöriger Einleitungssatz bleiben zusammen, wenn sie logisch einen Satz bilden.

19. Erfinde keine grammatischen Eigenschaften, Bedeutungen oder Regeln.

20. Wenn ein ungarisches Wort mehrere Bedeutungen haben kann, erkläre die Bedeutung, die es im konkreten Satz besitzt.

21. Die Erklärung darf NICHT an ein angenommenes Lernniveau angepasst werden. Vereinfache oder überspringe keine grammatische Struktur nur deshalb, weil sie fortgeschritten sein könnte.

22. Gib ausschließlich das fertige JSON aus.


==================================================
REFERENZBEISPIEL
==================================================

Das folgende Beispiel zeigt die gewünschte Art und Granularität der Erklärung.

Der Beispielsatz liegt ungefähr auf B1-Niveau und enthält etwa 15 Wörter.

UNGARISCH:

Amikor tegnap hazaértem, gyorsan megfőztem a vacsorát, mert este néhány régi barátom váratlanul meglátogatott bennünket.

Bei {{TARGET_LANGUAGE}} = Deutsch wäre eine gute Ausgabe beispielsweise:

[
  {
    "hu": "Amikor tegnap hazaértem, gyorsan megfőztem a vacsorát, mert este néhány régi barátom váratlanul meglátogatott bennünket.",
    "items": [
      {
        "term": "Amikor tegnap hazaértem",
        "explanation": "„Amikor“ bedeutet hier „als“ und leitet einen temporalen Nebensatz ein. „Hazaértem“ bedeutet „ich kam nach Hause“: „haza“ bezeichnet die Richtung nach Hause und die Endung von „értem“ zeigt die 1. Person Singular in der Vergangenheit.",
        "example_hu": "Amikor hazaértem, már sötét volt.",
        "example_translation": "Als ich nach Hause kam, war es schon dunkel."
      },
      {
        "term": "gyorsan",
        "explanation": "„Gyorsan“ bedeutet „schnell“. Die Endung „-an“ bildet hier aus dem Adjektiv „gyors“ ein Adverb und beschreibt, wie die Handlung ausgeführt wird.",
        "example_hu": "Péter gyorsan fut.",
        "example_translation": "Péter läuft schnell."
      },
      {
        "term": "megfőztem a vacsorát",
        "explanation": "„Megfőztem“ bedeutet hier „ich kochte/zubereitete“. Die Verbform steht in der 1. Person Singular der Vergangenheit und verwendet die bestimmte Konjugation, weil mit „a vacsorát“ ein bestimmtes Objekt folgt. „Vacsorát“ ist die Akkusativform von „vacsora".",
        "example_hu": "Megfőztem a levest.",
        "example_translation": "Ich habe die Suppe gekocht."
      },
      {
        "term": "mert",
        "explanation": "„Mert“ bedeutet „weil“ und leitet eine Begründung ein. Im Ungarischen verändert sich die Wortstellung danach nicht nach denselben Regeln wie in einem deutschen Nebensatz.",
        "example_hu": "Otthon maradok, mert esik az eső.",
        "example_translation": "Ich bleibe zu Hause, weil es regnet."
      },
      {
        "term": "este néhány régi barátom",
        "explanation": "„Este“ bedeutet „am Abend“. Nach „néhány“ („einige“ oder „ein paar“) steht das ungarische Nomen im Singular. Deshalb steht „barátom“ und nicht eine Pluralform. Die Endung „-om“ zeigt außerdem den Besitz: „mein Freund“, hier sinngemäß „einige meiner alten Freunde“.",
        "example_hu": "Néhány barátom Budapesten él.",
        "example_translation": "Einige meiner Freunde leben in Budapest."
      },
      {
        "term": "váratlanul",
        "explanation": "„Váratlanul“ bedeutet „unerwartet“. Die Form wird hier als Adverb verwendet und beschreibt die Art und Weise des Besuchs.",
        "example_hu": "Váratlanul megérkezett Anna.",
        "example_translation": "Anna kam unerwartet an."
      },
      {
        "term": "meglátogatott bennünket",
        "explanation": "„Meglátogatott“ bedeutet „besuchte“. Das Subjekt ist „néhány régi barátom“. „Bennünket“ bedeutet „uns“ und steht als direktes Objekt im Akkusativ.",
        "example_hu": "Tegnap meglátogatott minket Péter.",
        "example_translation": "Gestern hat Péter uns besucht."
      }
    ]
  }
]


==================================================
WAS DAS REFERENZBEISPIEL FESTLEGT
==================================================

Orientiere dich bei allen Ausgaben an dieser Granularität:

- Nicht jedes Wort benötigt eine eigene Erklärung.
- Ein einzelnes Wort erhält eine eigene Einheit, wenn daran etwas Lernenswertes zu erklären ist.
- Zusammengehörige grammatische Konstruktionen werden gemeinsam erklärt.
- Komplexere Satzteile können als Wortgruppe behandelt werden.
- Die Anzahl der Einheiten richtet sich nach dem Inhalt des Satzes und ist nicht fest vorgegeben.
- Bei einem Satz ähnlicher Länge sind ungefähr 5 bis 8 Erklärungseinheiten meist sinnvoll.
- Bei kurzen oder einfachen Sätzen können es entsprechend weniger sein.
- Bei komplexen Sätzen dürfen es mehr sein.
- Entscheidend ist eine vollständige und didaktisch sinnvolle Abdeckung, nicht eine bestimmte Anzahl von Einträgen.

Das Referenzbeispiel definiert die gewünschte Struktur und Detailtiefe. Kopiere seine Inhalte nicht auf andere Sätze, sondern analysiere jeden neuen Satz eigenständig.


==================================================
QUALITÄTSKONTROLLE
==================================================

Prüfe vor der Ausgabe intern:

- Sind alle wichtigen Bestandteile des Satzes ausreichend erklärt?
- Wurden zusammengehörige Elemente sinnvoll gruppiert?
- Wurde unnötige Wort-für-Wort-Zerlegung vermieden?
- Sind alle grammatischen Aussagen korrekt?
- Passen die Erklärungen tatsächlich zur verwendeten ungarischen Form?
- Sind die zusätzlichen ungarischen Beispielsätze korrekt?
- Zeigt jeder Beispielsatz wirklich den erklärten Sachverhalt?
- Sind die Übersetzungen natürlich und korrekt?
- Ist die Erklärung unabhängig von einem Lernniveau?
- Ist das Ergebnis valides JSON?

Korrigiere erkannte Fehler vor der Ausgabe.

Gib anschließend ausschließlich das fertige JSON aus.


==================================================
UNGARISCHER TEXT
==================================================

{{HU_TEXT}}
```

---

## 6. Minimal integration example

```ts
const MODE_3_PROMPT = `...full prompt text...`;

const response = await callAI({
  system: MODE_3_PROMPT.replaceAll("{{TARGET_LANGUAGE}}", targetLanguage),
  user: hungarianText
});
```

Expected parsed result:

```ts
type TutorMode3Item = {
  term: string;
  explanation: string;
  example_hu: string;
  example_translation: string;
};

type TutorMode3Sentence = {
  hu: string;
  items: TutorMode3Item[];
};

type TutorMode3Response = TutorMode3Sentence[];
```

---

## 7. Validation rules

After receiving the AI response:

1. Parse JSON
2. Root must be an array
3. Each item must contain:
   - `hu`
   - `items`
4. Each `items` entry must contain:
   - `term`
   - `explanation`
   - `example_hu`
   - `example_translation`

If JSON is invalid, retry once with:

```text
Return the result again as valid JSON matching the required structure. Do not add any other text.
```

---

## 8. Important notes

- This is **Mode 3** on the Tutor page.
- The explanation is **not level-dependent**.
- The selected UI language is only the **output language** for the explanation and example translation.
- The Hungarian source text should be passed unchanged.
- Use UTF-8.
- No Markdown rendering is required for the AI output itself.
