# Tutor and translation benchmark: Gemini vs DeepSeek

> **Do not run this on Markus's texts any more (22 October 2026).** Markus
> decided all AI in Forditva runs in the EU only. This tool calls DeepSeek
> (China) and the Gemini Developer API (no EU location), and the app no
> longer has a DeepSeek path. It is kept as a record of the comparison.

A small program outside the app that runs Markus's controlled comparison
(`DEVELOPER_HANDOFF_EN.md`, 12 October 2026). It does not touch the app,
WIU charging or the Token Server.

## What it runs

- **Tutor:** the 120 runs in `input/run_manifest.json`: 10 sentences from
  `input/test_sentences.json`, two models, and per sentence Mode 1 at levels
  05/30/60/90, Mode 2 (Decoder, German profile) and Mode 3. Explanation
  language German.
- **Translation:** the three texts in `input/translation_texts.txt`
  (Hungarian original, English and German reference). Hungarian into German
  and English, and German and English into Hungarian, on both models.

The prompts are the app's production prompts (`lib/tutor/tutor_core.dart`,
`lib/services/translation_prompts.dart`). The Tutor prompts are identical to
Markus's handoff files (checked byte for byte). Reference translations and
review notes are never sent to the models.

## Settings

| | Gemini | DeepSeek |
|---|---|---|
| Tutor model | `gemini-3.8-flash` (pinned) | `deepseek-flash` (DeepSeek-V4.1-Flash) |
| Tutor settings | temperature 0.2, JSON output mode, thinking off, max 32,768 output tokens | temperature 0.2, thinking disabled, JSON requested by the prompt, max 32,768 output tokens |
| Translation model | `gemini-3.5-flash-lite` (pinned; the app's translation model) | `deepseek-flash`, thinking disabled |
| Translation settings | temperature 0 | temperature 0 |

Differences to disclose:

- DeepSeek's JSON mode (`response_format: json_object`) cannot return a
  top-level array, and in a first run 19 of 40 Mode 1 answers came back as a
  single object. The default therefore leaves it out; `--deepseek-json-mode`
  turns it on.
- On Gemini 3.8 Flash, "thinking off" still leaves a few thinking tokens;
  they are reported and charged.
- The app's Tutor uses Gemini **with** thinking by default ("accurate") and
  without it only for "Answer now". This benchmark compares the
  non-thinking setups, as the handoff asks.
- No DeepSeek model ID is pinned more precisely than `deepseek-flash`;
  each run records the model name and `system_fingerprint` DeepSeek returns.

## Prices used for USD

Verified on 12 October 2026 (ai.google.dev/gemini-api/docs/pricing,
api-docs.deepseek.com/quick_start/pricing), USD per 1M tokens:

| Model | Input | Cached input | Output (incl. thinking) |
|---|---|---|---|
| gemini-3.8-flash (until 31 Dec 2026) | 0.75 | 0.075 | 3.75 |
| gemini-3.8-flash (from 1 Jan 2027) | 1.50 | 0.15 | 7.50 |
| gemini-3.5-flash-lite | 0.30 | 0.03 | 2.50 |
| deepseek-flash, peak (Mon-Fri 01-04 and 06-10 UTC) | 0.30 | 0.006 | 1.20 |
| deepseek-flash, off-peak | 0.15 | 0.003 | 0.60 |

DeepSeek's `completion_tokens` already include reasoning tokens; Gemini
reports thinking separately (`thoughtsTokenCount`) and both are added to
output there. Chinese public holidays (off-peak at DeepSeek) are not
modelled.

## How to run

From the repo root, with `GEMINI_API_KEY` and `DEEPSEEK_API_KEY` in `.env.dev` (not bundled into the app):

```
dart run tool/tutor_benchmark/tutor_benchmark.dart
```

Options: `--only tutor|translation`, `--cases T01,T02`,
`--providers gemini,deepseek`, `--modes level_focus,decoder,structured_analysis`,
`--concurrency 6`, `--deepseek-json-mode`.

To change models or settings, edit `tutorSetups` / `translationSetups` at the
top of `tutor_benchmark.dart` (and the price table in `usdFor` for a new
model).

## Output

`build/tutor_benchmark/<timestamp>/`:

- `report.html`: everything side by side with model names, plus the summary.
- `report_blind.html`: the same without names (A/B assigned at random per
  comparison) for unbiased scoring; `blind_key.json` resolves A/B.
- `scores.csv`: empty score sheet (1-5 for grammatical accuracy, learner
  usefulness, natural German, mode compliance) per comparison and side.
- `results.json`: every run and every attempt, with the untouched raw
  provider response, parsed JSON, validation results, raw usage metadata,
  token counts, response time and USD.
- `summary.csv`: per model, mode and level: runs, valid first/final, retries,
  average time and tokens, total and per-1,000 USD.

Automatic checks (necessary, not sufficient): valid JSON, top-level array
with exactly one item, source sentence unchanged, Mode 1 level and 1-3
complete items, Mode 2 exactly `hu`/`direct`/`correct`, Mode 3 complete items.
They cannot judge Hungarian grammar; that needs human review.
