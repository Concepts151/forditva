import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'gemini_cost.dart';
import 'token_balance.dart';

class GeminiTranslator {
  final GenerativeModel _model;

  GeminiTranslator()
    : _model = GenerativeModel(
        // flash-lite is markedly faster and does little/no "thinking",
        // which is what was adding latency to every translation.
        model: 'gemini-flash-lite-latest',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
      );

  /// Deducts this response's real-cost-weighted WIU price from the balance.
  void _recordUsage(GenerateContentResponse response) {
    final usage = response.usageMetadata;
    TokenBalance.instance.spendFractional(
      geminiWiuCost(
        promptTokens: usage?.promptTokenCount ?? 0,
        outputTokens: billableOutputTokens(
          prompt: usage?.promptTokenCount ?? 0,
          candidates: usage?.candidatesTokenCount ?? 0,
          total: usage?.totalTokenCount,
        ),
      ),
    );
  }

  static const Map<String, String> _uiLanguageNames = {
    'DE': 'German',
    'EN': 'English',
    'HU': 'Hungarian',
  };

  Future<String> translate(
    String inputText,
    String fromLang,
    String toLang, {
    bool explain = false,
    String level = 'A2',
    // Language the Tutor explanation itself is written in. Must be the app's
    // UI language (e.g. German), not the content languages being translated
    // (fromLang/toLang), which is what was causing explanations to come out
    // in whatever the document's input language happened to be.
    String uiLanguage = 'EN',
  }) async {
    if (!explain) {
      // Dedicated stateless translation engine. Strict rules live in the
      // systemInstruction (a hard boundary from the data), temperature 0 makes
      // it deterministic, and the raw text is sent as the user message with no
      // surrounding quotes — all to stop flash-lite "chatting" or adding quotes.
      final translateModel = GenerativeModel(
        model: 'gemini-flash-lite-latest',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
        systemInstruction: Content.system('''
You are a precise literal translation engine.
Task: Translate the user's text from $fromLang to $toLang.

Rules:
- Translate exactly what is written. Do NOT omit any words, adjectives, or conversational elements present in the source text.
- Do NOT add quotation marks, commentary, punctuation, or formatting.
- Output ONLY the raw translation string.
'''),
        generationConfig: GenerationConfig(temperature: 0.0),
      );

      final response = await translateModel.generateContent([
        Content.text(inputText),
      ]);
      _recordUsage(response);
      return response.text?.trim() ?? '';
    } else {
      // Explanation mode with level adaptation
      final explanationLanguage = _uiLanguageNames[uiLanguage] ?? uiLanguage;
      final prompt = '''
You are a highly skilled Hungarian language tutor specialized in CEFR levels. The student is at level $level.

Your task: Analyze and explain the following Hungarian sentence:
"$inputText"

Write your entire explanation (grammar_explanation and key_vocabulary) in $explanationLanguage, since that is the student's own language. Only Hungarian words/phrases being explained should stay in Hungarian; everything else must be in $explanationLanguage.

Step-by-step process for your analysis:
1. First, identify the main verb and its tense/mood.
2. Identify the word order and whether it follows the default (topic-comment) structure or has an emphasis.
3. Identify all suffixes (case endings, possessive, plural, verb conjugations) and explain their function.
4. Note any vowel harmony changes or linking vowels.
5. Identify if any verb prefixes are present and whether they are attached or separated.

Adapt explanations based on the student's level:

- If level is A1:
    - Use extremely simple and clear language.
    - Focus only on: basic word order, present tense, definite vs. indefinite conjugation (only if present), singular/plural, and the most basic suffixes (-ban/-ben, -nál/-nél).
    - Avoid terminology like "accusative", "dative", "mood", "prefix". Instead say "object form", "to/for whom", "direction".
    - Introduce only 2–3 new vocabulary words from the sentence. Ignore the rest.

- If level is A2:
    - Use simple but more detailed explanations.
    - Cover: accusative (-t), dative (-nak/-nek), basic past tense, common suffixes (-ból/-ből, -hoz/-hez/-höz, -on/-en/-ön).
    - Explain basic verb conjugation (definite/indefinite) if relevant.
    - Introduce 3–5 new words with simple example sentences for each.

- If level is B1:
    - Provide comprehensive grammar explanations.
    - Cover: multiple cases in one sentence, verb prefixes (meg-, el-, ki-, be-) and their meaning, conditional mood, subjunctive, participles (-ó/-ő, -t/-tt), complex word order with emphasis.
    - Explain idiomatic phrases and offer 1–2 synonyms for key vocabulary.
    - Mention if the sentence is formal or informal.

Additional rules for ALL levels (critical):
- Never use linguistic jargon without immediate plain-language translation (e.g., say "this is the object form" not "accusative case").
- Always explain WHY a suffix or word order is used, not just WHAT it is.
- Provide 1 short, level-appropriate example for the most important grammar point.
- Do NOT explain words the learner likely already knows at their level (e.g., basic greetings, numbers, common verbs like van/lesz).
- Always mention if the sentence is neutral, formal, or colloquial, because this is often not obvious to learners.
- If the sentence contains a common mistake trap (e.g., similarity to German/English), warn the student.

Output format (strict JSON, no extra text, no markdown formatting inside the JSON values):
{
  "grammar_explanation": "...",
  "key_vocabulary": "...",
  "translation": "..."
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      _recordUsage(response);
      final text = response.text?.trim() ?? '';

      return text;
    }
  }

  Stream<String> streamTranslate(
    String input,
    String from,
    String to, {
    bool explain = false,
  }) async* {
    final full = await translate(input, from, to, explain: explain);
    for (int i = 0; i < full.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield full[i];
    }
  }

  Future<String> detectLanguage(String inputText) async {
    // flash-lite (the default _model) does little "thinking" and was
    // misidentifying short/diacritic-heavy text — e.g. genuine Hungarian
    // read as Portuguese or German (Markus, 2026-07-10). Language ID needs
    // more care than a plain translation, so use the full model here even
    // though it's slower; this call only runs once per image.
    final detectModel = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      generationConfig: GenerationConfig(temperature: 0.0),
    );
    // Constrained answer set + an explicit "unsure" escape hatch. The old
    // open-ended prompt forced a guess, and on noisy OCR samples (numbers,
    // codes, mixed fragments) that guess skewed toward EN, producing false
    // "detected EN" warnings on documents with no English in them at all
    // (Markus, 2026-07-15, a fully Hungarian utility bill).
    final prompt = '''
The following text was extracted from a photographed document by OCR. It may contain numbers, dates, reference codes and OCR noise; ignore those and judge only the natural-language words.

Which language are the natural-language words written in? Reply with exactly one of: HU, DE, EN, NL, FR, ES, RU, IT, UNKNOWN

Reply UNKNOWN if there are too few natural-language words to be sure, or if none of the listed languages fits. No other words in your reply.

$inputText
''';
    final response = await detectModel.generateContent([Content.text(prompt)]);
    _recordUsage(response);
    return response.text?.trim().toUpperCase() ?? '';
  }
}
