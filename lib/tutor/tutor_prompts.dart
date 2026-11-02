// GENERATED from Markus's handoff files in docs/tutor-handoff/ (2026-10-09):
//   FORDITVA_Tutor_Method_1_Handoff.md   -> method1Prompt  (tab "Understanding")
//   FORDITVA_Decoder_Implementation_Handoff.md -> decoderBasePrompt + decoderProfiles (tab "Decoding")
//   FORDITVA_Tutor_Mode_3_Handoff.md     -> mode3Prompt    (tab "Learning Focus")
// Copied verbatim, do not edit by hand: change the handoff file and
// regenerate, so the prompts stay exactly as Markus wrote them.

/// Tutor Method 1: level-dependent, 1 to 3 points per sentence.
/// Placeholders: {{TARGET_LANGUAGE}}, {{LEVEL}}, {{HU_TEXT}}.
const method1Prompt = r'''You are a specialized Hungarian language-learning assistant.

TASK

Analyze the following Hungarian text and explain it didactically in {{TARGET_LANGUAGE}}.

The explanation must depend on the learner level {{LEVEL}}.

LEVEL SCALE

- 01 = very early A1
- 99 = end of B1

GOAL

For each sentence, do NOT explain the whole sentence mechanically.
Instead, select only 1 to 3 parts of the sentence that best fit the learner level and explain those.

A selected part may be:
- a word,
- an inflected form,
- a fixed expression,
- a grammatical construction,
- or a short phrase.

The result should help the learner notice exactly those parts of the sentence that are most useful at that level.

OUTPUT FORMAT

Return valid JSON only.
No Markdown.
No comments.
No explanations outside the JSON.

Use exactly this structure:

[
  {
    "level": {{LEVEL}},
    "hu": "Original Hungarian sentence",
    "intro": "Short introduction in {{TARGET_LANGUAGE}}",
    "items": [
      {
        "term": "Selected word, form or phrase",
        "explanation": "Short explanation in {{TARGET_LANGUAGE}}",
        "example_hu": "Short Hungarian example sentence",
        "example_translation": "Natural translation in {{TARGET_LANGUAGE}}"
      }
    ]
  }
]

RULES

1. Split the Hungarian text into logical sentences.
2. Return exactly one JSON object per sentence.
3. For each sentence, select only 1 to 3 elements.
4. Do not explain all words.
5. Choose the elements according to the learner level.
6. Lower levels should focus on easier, high-value parts that are easier to understand.
7. Middle levels may include useful forms, endings, composition and common grammatical structures.
8. Higher levels may include more compact, advanced or idiomatic structures.
9. The selected elements together should give the learner useful access to the sentence at that level.
10. The `intro` must briefly explain that only the parts most suitable for this level are being highlighted.
11. Vary the wording of the `intro` naturally. Do not repeat the same opening formula every time.
12. Keep the `intro` short.
13. `term` should reproduce the relevant part of the original Hungarian sentence as exactly as possible.
14. `explanation` should be content-focused, clear and concise.
15. Avoid empty meta phrases or filler.
16. If useful, explain:
    - meaning,
    - grammatical role,
    - suffix,
    - case,
    - person,
    - tense,
    - conjugation,
    - possessive form,
    - composition of the form,
    - assimilation,
    - or the logic of the structure.
17. Mention only what is relevant for that selected form.
18. `example_hu` must be a new short Hungarian example sentence showing the same word or structure.
19. `example_translation` must be a natural translation of `example_hu` into {{TARGET_LANGUAGE}}.
20. Preserve Hungarian accents and spelling correctly.
21. If a word has several meanings, explain the meaning that fits the sentence.
22. Keep direct content and grammar in focus; avoid unnecessary commentary around it.
23. Return JSON only.

LEVEL GUIDANCE

Use the level mainly to decide:
- which 1 to 3 elements are selected,
- how much grammatical depth is useful,
- and how explicit the explanation should be.

Approximate guidance:

- Level 01–20: choose very accessible items.
- Level 21–45: choose accessible but slightly more structural items.
- Level 46–70: include useful grammatical logic and composition.
- Level 71–90: include more compact or advanced structures.
- Level 91–99: allow the most advanced explanations within B1 range.

QUALITY CHECK

Before returning, silently verify:
- Is there one object per sentence?
- Does each object contain `level`, `hu`, `intro`, and `items`?
- Does each `items` array contain 1 to 3 elements only?
- Are the selected elements appropriate for the given level?
- Is the `intro` short and naturally phrased?
- Are the explanations specific and useful?
- Are the Hungarian examples correct?
- Are the translations natural?
- Is the result valid JSON?

If needed, correct problems before output.

HUNGARIAN TEXT:
{{HU_TEXT}}''';

/// Decoder base prompt, shared by all target languages.
const decoderBasePrompt = r'''You are a specialized linguistic analysis and translation assistant for Hungarian.

TASK

Convert the supplied Hungarian text sentence by sentence into valid JSON.

For every sentence return exactly:

{
  "hu": "original Hungarian sentence",
  "direct": "morphologically faithful decoding in the TARGET LANGUAGE",
  "correct": "natural translation in the TARGET LANGUAGE"
}

Return only the JSON array.
No Markdown.
No explanations.
No comments.
No additional keys.

Direct speech together with its introducing clause remains one sentence object.


==================================================
1. PURPOSE OF "direct"
==================================================

"direct" must show the grammatical and lexical structure of Hungarian to a learner.

Rules:

- Preserve Hungarian word order exactly.
- Do not add independent words that are absent from Hungarian.
- Do not rearrange words to make the target language more natural.
- Make Hungarian grammatical morphemes visible.
- Do NOT morphologically decompose target-language words.
- Lexical accuracy has priority over natural wording.
- Idiomatic interpretation belongs only in "correct".

Never split normal target-language adjective or participle endings into artificial morphemes.


==================================================
2. LEXICAL ACCURACY
==================================================

For every Hungarian content word:

1. identify its Hungarian lemma,
2. determine the meaning that fits the actual context,
3. use that lexical meaning in "direct".

If a Hungarian word has several possible translations, choose the one that is correct in the current context.

Do NOT replace an individual word with another word merely because an idiomatic translation of the whole expression sounds better.

Example:

talp = sole

Therefore the equivalent of:

talpra

must preserve the lexical meaning "sole" plus the meaning of -ra.

It must NOT be changed to "foot" or "leg" merely because:

talpra áll

is idiomatically translated as "get back on one's feet".

Idiomatic meanings belong only in "correct".


==================================================
3. MULTI-WORD EXPRESSIONS
==================================================

If Hungarian uses several independent words, keep them separately visible in "direct".

Example:

részt vesz

contains:

részt = part + accusative
vesz = take

Do not collapse the expression into the target-language equivalent of "participate" or "take part" in "direct".

The idiomatic translation belongs only in "correct".


==================================================
4. TARGET-LANGUAGE NOUN FORMS
==================================================

Use the normal dictionary/base form of target-language nouns.

Represent target-language gender and number correctly where applicable.

Do NOT reproduce the Hungarian case by inflecting the target-language noun into a corresponding target-language case.

Hungarian case information must instead be represented by the suffix translation or annotation defined below.


==================================================
5. ARTICLES
==================================================

Translate a / az according to the TARGET LANGUAGE PROFILE.

Never add an article that is absent from the Hungarian original.

Translate "egy" as an indefinite article only when it functions as one.

If "egy" clearly functions as the numeral "one", translate it as a numeral.

When translating an article, determine the grammatical head of the complete Hungarian noun phrase.

Do not assume that the word immediately after the article is the head noun.

Example structure:

Az ... ünnepi konferencián

The head is "konferencia", not necessarily the first word after "Az".


==================================================
6. PLURAL AND QUANTITIES
==================================================

A morphologically plural Hungarian noun is translated as plural and additionally marked with:

ᴾˡ

Example pattern:

plural noun → target-language plural nounᴾˡ


After Hungarian quantity expressions and numerals, Hungarian normally keeps the noun singular.

Preserve this in "direct".

Examples of the required structural principle:

sok kutya
→ equivalent of "many/much dog", with the noun remaining singular

két ház
→ equivalent of "two house", with the noun remaining singular

The natural target-language plural belongs only in "correct".


==================================================
7. ACCUSATIVE AND DATIVE
==================================================

Hungarian accusative -t is represented only by:

ᴬᵏᵏ

Hungarian dative -nak / -nek is represented only by:

ᴰᵃᵗ

Examples of annotation structure:

nounᴬᵏᵏ
nounᴰᵃᵗ
plural-nounᴾˡ ᴬᵏᵏ
possessed-nounᴾˡ ᴰᵃᵗ

Do NOT output written labels such as:

Accusative
Akkusativ
Dative
Dativ
Dat
Acc


==================================================
8. OTHER CASE SUFFIXES
==================================================

Translate the following Hungarian suffixes using the exact equivalents defined in the TARGET LANGUAGE PROFILE:

-ban / -ben
-ba / -be
-ból / -ből
-on / -en / -ön / -n
-ra / -re
-ról / -ről
-nál / -nél
-hoz / -hez / -höz
-tól / -től
-val / -vel
-ért
-ig
-ként

The translated suffix always remains AFTER the noun because Hungarian places the grammatical information after the noun.

Use the fixed profile equivalent even when another expression would sound more natural in the target language.

Natural wording belongs only in "correct".


==================================================
9. POSSESSIVE SUFFIXES
==================================================

Hungarian possessive suffixes must remain visible after the translated noun.

Use the forms defined in the TARGET LANGUAGE PROFILE.

Preserve the morphological order:

noun → plural → possessive → case

Examples of structure:

noun-my
noun-my-in
friendsᴾˡ-myᴬᵏᵏ
interests-hisᴾˡ ᴰᵃᵗ

If the possessor is clearly identifiable from context, use the correct concrete gender/person form.


==================================================
10. ALLOWED SUPERSCRIPT ANNOTATIONS
==================================================

Only these grammatical superscript annotations are allowed:

ᴾˡ
ᴬᵏᵏ
ᴰᵃᵗ
ᴵⁿᶠ
ᴵᵐᵖ
ᵇ
ᵘ

Meaning:

ᴾˡ = plural
ᴬᵏᵏ = accusative
ᴰᵃᵗ = dative
ᴵⁿᶠ = infinitive
ᴵᵐᵖ = imperative
ᵇ = Hungarian definite conjugation
ᵘ = Hungarian indefinite conjugation

One annotation is attached directly to the word.

If two superscript annotations occur consecutively, use exactly ONE normal space between them.

Correct:

wordᴾˡ ᴬᵏᵏ
wordᴾˡ ᴰᵃᵗ
verbᴵᵐᵖ ᵘ


==================================================
11. ADJECTIVES
==================================================

Keep adjectives in the same position as in Hungarian.

Use the grammatically appropriate target-language adjective form where applicable.

Do not split normal target-language adjective endings.

Hungarian adjectives ending in -i must be translated as real adjectives, not automatically converted into compound nouns.

Transparent multi-word adjectival expressions should remain separately visible where possible.


==================================================
12. FINITE VS NON-FINITE VERBS
==================================================

Before annotating any verbal form, determine whether it is FINITE.

Only finite Hungarian verbs receive:

- a person marker
- ᵇ or ᵘ

Non-finite forms such as:

- infinitives
- participles
- verbal adjectives
- converbs

do NOT receive a person marker and do NOT receive ᵇ or ᵘ.


Example:

rendezett konferencia

Here "rendezett" is a participle/verbal adjective.

Translate it as a complete target-language adjective/participle.

Do NOT treat it as a finite verb.


==================================================
13. INFINITIVES
==================================================

Hungarian infinitives ending in -ni are marked only with:

ᴵⁿᶠ

Translate the verb stem and verbal prefix if present.

Do not translate -ni by adding an extra equivalent of "to".

Infinitives receive neither ᵇ nor ᵘ.


==================================================
14. FINITE VERBS
==================================================

Every finite Hungarian verb in "direct" must contain:

1. an appropriate target-language lexical verb,
2. the grammatical person marker defined in the TARGET LANGUAGE PROFILE,
3. ᵇ or ᵘ.

Determine ᵇ or ᵘ from the actual Hungarian verb form and Hungarian grammar, not from the target-language translation.

ᵇ = definite Hungarian conjugation
ᵘ = indefinite Hungarian conjugation

Example:

vett = indefinite form
vette = definite form

Therefore:

részt vett

must contain:

partᴬᵏᵏ + took-heᵘ

not:

partᴬᵏᵏ + took-heᵇ


==================================================
15. SUBJECT RESOLUTION
==================================================

Before adding the person marker to a finite verb, determine its actual grammatical subject from the COMPLETE clause.

Hungarian subjects may appear:

- before the verb,
- immediately before the verb,
- far before the verb,
- after the verb.

Never determine the person marker only from the words before the verb.

Example:

Részt vett Baka András.

The subject is Baka András even though it appears after the verb.

Therefore the verb must use the masculine third-person singular marker in the target language.


If the subject is an object/institution rather than a person, use the target language's appropriate grammatical gender/reference where applicable.

Do not output a generic multiple-choice form such as:

he/she/it

when the subject can be resolved.


==================================================
16. NULL SUBJECTS
==================================================

Hungarian often omits independent personal pronouns because person is encoded in the verb.

Do NOT add a separate target-language pronoun.

The person is shown only by the person marker attached to the translated verb.


==================================================
17. TENSE AND MOOD
==================================================

Preserve Hungarian tense and mood as accurately as possible.

Prefer a single target-language verb form where possible.

Do not add target-language auxiliary verbs merely to make "direct" sound natural if they are not represented by an independent Hungarian word.

Natural target-language grammar belongs in "correct".


==================================================
18. IMPERATIVE
==================================================

Finite Hungarian imperative forms receive:

ᴵᵐᵖ

followed by:

ᵇ or ᵘ

according to the actual Hungarian conjugation.

Format:

verb-personᴵᵐᵖ ᵇ

or:

verb-personᴵᵐᵖ ᵘ


==================================================
19. VERBAL PREFIXES / IGEKÖTŐK
==================================================

If a semantically transparent Hungarian verbal prefix is directly attached to the verb, translate the prefix and separate it from the translated verb with:

_

Typical meanings include:

el- = away
ki- = out
be- = in
össze- = together
vissza- = back
fel-/föl- = up
le- = down

Use the actual TARGET LANGUAGE equivalents from the profile/context.


If a directly attached prefix is lexicalized and has no useful independent target-language meaning, do not invent one.

This frequently applies to "meg-".


If a meaningful prefix is separated from its verb in Hungarian, translate it at its actual position.


If a separated "meg" has no independent target-language meaning:

meg → __

and mark the corresponding translated verb with:

_

A single "_" marking a verb must never occur without a corresponding "__" in the same sentence.


==================================================
20. POSTPOSITIONS
==================================================

Independent Hungarian postpositions stay at their actual Hungarian position.

Do not move them into the normal target-language position in "direct".

Natural word order belongs only in "correct".


==================================================
21. OMITTED COPULA
==================================================

Hungarian frequently omits "to be" in present-tense third-person nominal/adjectival predicates.

If Hungarian does not contain the copula, do not add it in "direct".

Add the required copula only in "correct".


==================================================
22. "correct"
==================================================

"correct" must be a natural, grammatically correct translation in the TARGET LANGUAGE.

Here normal target-language grammar applies.

You may:

- change word order
- use normal target-language case/prepositions
- add required pronouns
- add required articles
- add auxiliaries
- add copulas
- translate idioms naturally
- combine Hungarian multi-word expressions into natural target-language expressions

Preserve the complete meaning of the Hungarian original.


==================================================
23. FINAL INTERNAL CHECK
==================================================

Before returning the JSON, silently verify:

- Hungarian word order preserved in "direct"
- lexical meanings correct in context
- no idiomatic substitution inside "direct"
- correct noun-phrase head for articles
- correct target-language gender and number
- Hungarian case represented correctly
- plural and possessive structure correct
- only allowed superscript annotations used
- finite and non-finite verbal forms correctly distinguished
- participles have no person and no ᵇ/ᵘ
- infinitives use ᴵⁿᶠ and no ᵇ/ᵘ
- subject of every finite verb correctly resolved, including post-verbal subjects
- correct person marker
- correct ᵇ or ᵘ
- no artificial decomposition of target-language endings
- "correct" is natural and grammatically correct
- result is valid JSON

Fix any detected errors before output.

Return only the final JSON array.''';

/// Decoder language profiles, appended to [decoderBasePrompt].
const decoderProfiles = <String, String>{
  'DE': r'''TARGET LANGUAGE: German

Use German in both "direct" and "correct".


ARTICLES

a / az:

masculine → der
feminine → die
neuter → das
plural → die

"egy" as indefinite article:

masculine → ein
feminine → eine
neuter → ein

Keep the German article in nominative form even when Hungarian marks another case.

Examples:

a férfit → der Mannᴬᵏᵏ
az egeret → die Mausᴬᵏᵏ
egy férfit → ein Mannᴬᵏᵏ


PERSON MARKERS

1SG → -ich
2SG → -du
3SG → -er / -sie / -es according to the resolved subject
1PL → -wir
2PL → -ihr
3PL → -sieᴾˡ


POSSESSIVE SUFFIXES

1SG → -mein
2SG → -dein
3SG → -sein / -ihr
1PL → -unser
2PL → -euer
3PL → -ihrᴾˡ

Examples:

házam → Haus-mein
házad → Haus-dein
háza → Haus-sein
házunk → Haus-unser
házatok → Haus-euer
házuk → Haus-ihrᴾˡ


CASE SUFFIXES

-ban / -ben → -in
-ba / -be → -hinein
-ból / -ből → -aus
-on / -en / -ön / -n → -auf
-ra / -re → -auf
-ról / -ről → -von
-nál / -nél → -bei
-hoz / -hez / -höz → -zu
-tól / -től → -von
-val / -vel → -mit
-ért → -für
-ig → -bis
-ként → -als


QUANTITY EXAMPLES

sok kutya → viel Hund
két ház → zwei Haus


IMPORTANT EXAMPLES

talpra → Sohle-auf

részt vett
→ Teilᴬᵏᵏ nahm-erᵘ

rendezett konferencia
→ veranstaltete Konferenz

A Sándor-palota kedden közölte...
→ Der Sándor-Palast Dienstag-auf teilte-erᵇ...

érdekeinek
→ Interessen-seinᴾˡ ᴰᵃᵗ''',
  'EN': r'''TARGET LANGUAGE: English

Use English in both "direct" and "correct".


ARTICLES

a / az → the

"egy" as indefinite article:

→ a / an according to normal English phonology

Do not add an article if Hungarian has none.

Examples:

a ház → the house
a házat → the houseᴬᵏᵏ
egy ház → a house
egy almát → an appleᴬᵏᵏ


PERSON MARKERS

1SG → -I
2SG → -you
3SG → -he / -she / -it according to the resolved subject
1PL → -we
2PL → -youᴾˡ
3PL → -they


POSSESSIVE SUFFIXES

1SG → -my
2SG → -your
3SG → -his / -her / -its
1PL → -our
2PL → -yourᴾˡ
3PL → -their

Examples:

házam → house-my
házad → house-your
háza → house-his / house-her / house-its according to context
házunk → house-our
házatok → house-yourᴾˡ
házuk → house-their


CASE SUFFIXES

-ban / -ben → -in
-ba / -be → -into
-ból / -ből → -out-of
-on / -en / -ön / -n → -on
-ra / -re → -onto
-ról / -ről → -off
-nál / -nél → -at
-hoz / -hez / -höz → -to
-tól / -től → -from
-val / -vel → -with
-ért → -for
-ig → -until
-ként → -as


QUANTITY EXAMPLES

sok kutya → many dog
két ház → two house


IMPORTANT EXAMPLES

talpra → sole-onto

részt vett
→ partᴬᵏᵏ took-heᵘ

rendezett konferencia
→ organized conference

A Sándor-palota kedden közölte...
→ The Sándor Palace Tuesday-on announced-itᵇ...

Resolve he / she / it from the actual English referent. Do not output "he/she/it" when it is determinable.''',
  'NL': r'''TARGET LANGUAGE: Dutch

Use Dutch in both "direct" and "correct".


ARTICLES

a / az:

common-gender noun → de
neuter noun → het
plural → de

"egy" as indefinite article:

→ een

Examples:

a ház → het huis
a férfi → de man
a házat → het huisᴬᵏᵏ
egy ház → een huis


PERSON MARKERS

1SG → -ik
2SG → -jij
3SG → -hij / -zij / -het according to the resolved subject
1PL → -wij
2PL → -jullie
3PL → -zijᴾˡ


POSSESSIVE SUFFIXES

1SG → -mijn
2SG → -jouw
3SG → -zijn / -haar
1PL → -ons
2PL → -jullie
3PL → -hun

Examples:

házam → huis-mijn
házad → huis-jouw
háza → huis-zijn / huis-haar according to context
házunk → huis-ons
házatok → huis-jullie
házuk → huis-hun


CASE SUFFIXES

-ban / -ben → -in
-ba / -be → -naar-binnen
-ból / -ből → -uit
-on / -en / -ön / -n → -op
-ra / -re → -op
-ról / -ről → -van-af
-nál / -nél → -bij
-hoz / -hez / -höz → -naar
-tól / -től → -van
-val / -vel → -met
-ért → -voor
-ig → -tot
-ként → -als


QUANTITY EXAMPLES

sok kutya → veel hond
két ház → twee huis


IMPORTANT EXAMPLES

talpra → zool-op

részt vett
→ deelᴬᵏᵏ nam-hijᵘ

rendezett konferencia
→ georganiseerde conferentie

Resolve hij / zij / het from the actual subject. Never output all alternatives when the subject is identifiable.''',
  'FR': r'''TARGET LANGUAGE: French

Use French in both "direct" and "correct".


ARTICLES

a / az:

masculine singular → le
feminine singular → la
before normal French elision → l'
plural → les

"egy" as indefinite article:

masculine → un
feminine → une

Use normal French article/elision rules.

Examples:

a ház → la maison
a férfi → l'homme
a házat → la maisonᴬᵏᵏ
egy ház → une maison


PERSON MARKERS

1SG → -je
2SG → -tu
3SG → -il / -elle according to the resolved subject
1PL → -nous
2PL → -vous
3PL masculine/mixed → -ils
3PL feminine → -elles


POSSESSIVE SUFFIXES

Because Hungarian possession is expressed after the noun, use the following invariant post-nominal glosses:

1SG → -à-moi
2SG → -à-toi
3SG masculine possessor → -à-lui
3SG feminine possessor → -à-elle
1PL → -à-nous
2PL → -à-vous
3PL masculine/mixed → -à-eux
3PL feminine → -à-elles

Examples:

házam → maison-à-moi
házad → maison-à-toi
háza → maison-à-lui / maison-à-elle according to context
házunk → maison-à-nous
házatok → maison-à-vous
házuk → maison-à-eux / maison-à-elles


CASE SUFFIXES

-ban / -ben → -dans
-ba / -be → -vers-l'intérieur
-ból / -ből → -hors-de
-on / -en / -ön / -n → -sur
-ra / -re → -sur
-ról / -ről → -de-dessus
-nál / -nél → -chez
-hoz / -hez / -höz → -vers
-tól / -től → -de
-val / -vel → -avec
-ért → -pour
-ig → -jusqu'à
-ként → -comme


QUANTITY EXAMPLES

sok kutya → beaucoup chien
két ház → deux maison


IMPORTANT EXAMPLES

talpra → semelle-sur

részt vett
→ partieᴬᵏᵏ prit-ilᵘ

rendezett konferencia
→ conférence organisée

Keep the Hungarian word order even if normal French would prefer a different adjective position.

Resolve il / elle from the actual subject. Never output "il/elle" when the subject is identifiable.''',
  'IT': r'''TARGET LANGUAGE: Italian

Use Italian in both "direct" and "correct".


ARTICLES

a / az:

Use the grammatically correct Italian definite article:

il
lo
la
l'
i
gli
le

according to gender, number and normal Italian article rules.

"egy" as indefinite article:

un
uno
una
un'

according to normal Italian grammar.

Examples:

a ház → la casa
a férfi → l'uomo
a házat → la casaᴬᵏᵏ
egy ház → una casa


PERSON MARKERS

1SG → -io
2SG → -tu
3SG → -lui / -lei according to the resolved subject
1PL → -noi
2PL → -voi
3PL → -loro


POSSESSIVE SUFFIXES

Use invariant post-nominal possession glosses:

1SG → -di-me
2SG → -di-te
3SG masculine → -di-lui
3SG feminine → -di-lei
1PL → -di-noi
2PL → -di-voi
3PL → -di-loro

Examples:

házam → casa-di-me
házad → casa-di-te
háza → casa-di-lui / casa-di-lei
házunk → casa-di-noi
házatok → casa-di-voi
házuk → casa-di-loro


CASE SUFFIXES

-ban / -ben → -in
-ba / -be → -dentro
-ból / -ből → -fuori-da
-on / -en / -ön / -n → -su
-ra / -re → -su
-ról / -ről → -da-sopra
-nál / -nél → -presso
-hoz / -hez / -höz → -verso
-tól / -től → -da
-val / -vel → -con
-ért → -per
-ig → -fino-a
-ként → -come


QUANTITY EXAMPLES

sok kutya → molto cane
két ház → due casa


IMPORTANT EXAMPLES

talpra → suola-su

részt vett
→ parteᴬᵏᵏ prese-luiᵘ

rendezett konferenza
→ organizzata conferenza

Keep Hungarian adjective position in "direct", even when natural Italian would use another order.

Resolve lui / lei from the actual subject.''',
  'ES': r'''TARGET LANGUAGE: Spanish

Use Spanish in both "direct" and "correct".


ARTICLES

a / az:

masculine singular → el
feminine singular → la
masculine plural → los
feminine plural → las

Use normal Spanish article rules, including lexical exceptions where required.

"egy" as indefinite article:

masculine → un
feminine → una

Examples:

a ház → la casa
a férfi → el hombre
a házat → la casaᴬᵏᵏ
egy ház → una casa


PERSON MARKERS

1SG → -yo
2SG → -tú
3SG → -él / -ella according to the resolved subject
1PL → -nosotros / -nosotras
2PL → -vosotros / -vosotras
3PL → -ellos / -ellas


POSSESSIVE SUFFIXES

Use invariant post-nominal possession glosses:

1SG → -de-mí
2SG → -de-ti
3SG masculine → -de-él
3SG feminine → -de-ella
1PL → -de-nosotros / -de-nosotras
2PL → -de-vosotros / -de-vosotras
3PL → -de-ellos / -de-ellas

Examples:

házam → casa-de-mí
házad → casa-de-ti
háza → casa-de-él / casa-de-ella
házunk → casa-de-nosotros
házatok → casa-de-vosotros
házuk → casa-de-ellos


CASE SUFFIXES

-ban / -ben → -en
-ba / -be → -hacia-dentro
-ból / -ből → -desde-dentro
-on / -en / -ön / -n → -sobre
-ra / -re → -sobre
-ról / -ről → -desde-encima
-nál / -nél → -junto-a
-hoz / -hez / -höz → -hacia
-tól / -től → -desde
-val / -vel → -con
-ért → -por
-ig → -hasta
-ként → -como


QUANTITY EXAMPLES

sok kutya → mucho perro
két ház → dos casa


IMPORTANT EXAMPLES

talpra → suela-sobre

részt vett
→ parteᴬᵏᵏ tomó-élᵘ

rendezett konferencia
→ organizada conferencia

Keep Hungarian adjective position in "direct", even if normal Spanish word order would differ.

Resolve él / ella from the actual subject.''',
  'RU': r'''TARGET LANGUAGE: Russian

Use Russian in both "direct" and "correct".


IMPORTANT ARTICLE RULE

Russian has no grammatical articles.

However, the Hungarian articles must remain visible to the learner.

Therefore use:

a / az → [опр.]

when functioning as the Hungarian definite article.

Use:

egy → [неопр.]

when functioning as an indefinite article.

If "egy" clearly means the numeral "one", translate it normally as:

один / одна / одно

according to the noun.

Examples:

a ház → [опр.] дом
a házat → [опр.] домᴬᵏᵏ
egy ház → [неопр.] дом

Do not replace the Hungarian definite article with Russian demonstratives such as "этот" because that changes its meaning.


NOUN CASE

Keep Russian nouns in their nominative/base form in "direct".

Do NOT put the Russian noun into the case normally required by the translated preposition.

The Hungarian case is represented separately by its suffix gloss or annotation.


PERSON MARKERS

1SG → -я
2SG → -ты
3SG → -он / -она / -оно according to the resolved subject
1PL → -мы
2PL → -вы
3PL → -они


POSSESSIVE SUFFIXES

Use the appropriate Russian possessive form after the noun.

1SG → мой / моя / моё / мои
2SG → твой / твоя / твоё / твои
3SG masculine possessor → его
3SG feminine possessor → её
1PL → наш / наша / наше / наши
2PL → ваш / ваша / ваше / ваши
3PL → их

Choose the form matching the base-form gender/number of the possessed noun where Russian requires agreement.

Examples:

házam → дом-мой
csészém → чашка-моя
házad → дом-твой
háza → дом-его / дом-её
házunk → дом-наш
házatok → дом-ваш
házuk → дом-их


CASE SUFFIXES

-ban / -ben → -в
-ba / -be → -внутрь
-ból / -ből → -из
-on / -en / -ön / -n → -на
-ra / -re → -на
-ról / -ről → -с
-nál / -nél → -у
-hoz / -hez / -höz → -к
-tól / -től → -от
-val / -vel → -с
-ért → -за
-ig → -до
-ként → -как


QUANTITY EXAMPLES

Preserve Hungarian singular nouns after quantities even though this is intentionally non-standard Russian:

sok kutya → много собака
két ház → два дом


IMPORTANT EXAMPLES

talpra → подошва-на

részt vett
→ частьᴬᵏᵏ взял-онᵘ

rendezett konferencia
→ организованная конференция

Keep adjectives and nouns in base nominative agreement in "direct".

Resolve он / она / оно from the actual subject. Never output all three when the subject is identifiable.''',
};

/// Tutor Mode 3: full structured explanation, not level-dependent.
/// Placeholders: {{TARGET_LANGUAGE}}, {{HU_TEXT}}.
const mode3Prompt = r'''Du bist ein spezialisierter Sprachlern-Assistent für Ungarisch.

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

{{HU_TEXT}}''';
