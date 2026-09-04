# Translating Chrono

`describeCronTabExression( expression, locale )` turns a cron expression into
a human readable phrase. This file explains how those phrases are translated
and how to review or add a language.

## How it works

Chrono does not translate cron descriptions word by word. It recognises the
*shape* of an expression and then picks one whole message template for it, so
each language controls its own word order rather than inheriting English's.

* Templates live in `i18n/<locale>.json`, one file per language.
* `{1}` and `{2}` are placeholders filled in at runtime (a time, a day name,
  a number). Keep them, and put them where the language needs them — reordering
  them is expected and supported.
* `i18n/en.json` is the base bundle. Any key a language omits
  falls back to it, so a partial translation degrades one phrase at a time.
* A locale is resolved from least to most specific: `pt-BR` is served by
  `en.json`, then `pt.json`, then `pt_BR.json`. Both `pt-BR`
  and `pt_BR` are accepted.
* The one exception to that fallback is `ordinal_<n>`. Ordinal rules do not
  transfer between languages, so a per-day override is only ever read from the
  language's own bundle and never inherited from `en.json`.
* Month and day names are in the bundles too, as `month_1`...`month_12` and
  `dow_1`...`dow_7` (`dow_1` is Sunday). They are shipped as data rather than
  read from the engine, because `LSDateFormat()` does not exist on every CFML
  engine and Chrono should describe a cron identically everywhere.

## Review sheets

One page per language, showing the real output for every kind of expression
Chrono can describe. These are generated — regenerate them after editing a
bundle with:

```
box task run TranslationDocs
```

* [German (`de`)](docs/translations/de.md) — 7 key(s) missing, falling back to `en`
* [Greek (`el`)](docs/translations/el.md) — 7 key(s) missing, falling back to `en`
* [English (`en`)](docs/translations/en.md) — complete
* [Spanish (`es`)](docs/translations/es.md) — 7 key(s) missing, falling back to `en`
* [French (`fr`)](docs/translations/fr.md) — 6 key(s) missing, falling back to `en`
* [Indonesian (`id`)](docs/translations/id.md) — 7 key(s) missing, falling back to `en`
* [Italian (`it`)](docs/translations/it.md) — 6 key(s) missing, falling back to `en`
* [Japanese (`ja`)](docs/translations/ja.md) — 7 key(s) missing, falling back to `en`
* [Korean (`ko`)](docs/translations/ko.md) — 7 key(s) missing, falling back to `en`
* [Dutch (`nl`)](docs/translations/nl.md) — 7 key(s) missing, falling back to `en`
* [Polish (`pl`)](docs/translations/pl.md) — 7 key(s) missing, falling back to `en`
* [Portuguese (`pt`)](docs/translations/pt.md) — 6 key(s) missing, falling back to `en`
* [Romanian (`ro`)](docs/translations/ro.md) — 7 key(s) missing, falling back to `en`
* [Russian (`ru`)](docs/translations/ru.md) — 7 key(s) missing, falling back to `en`
* [Swahili (`sw`)](docs/translations/sw.md) — 7 key(s) missing, falling back to `en`
* [Turkish (`tr`)](docs/translations/tr.md) — 7 key(s) missing, falling back to `en`
* [Chinese (Simplified) (`zh`)](docs/translations/zh.md) — 7 key(s) missing, falling back to `en`

## What to look for when reviewing

1. Does each phrase read like something a person would write, in the register
   of a UI label? These strings appear in a schedule column, so short is good.
2. Is the word order right for the language — particularly `month_day`, which
   controls whether a date reads as "January 1st" or "1 January"?
3. Are the day-of-month ordinals right? `ordinal` is the pattern for every
   day, and `ordinal_<n>` overrides a single day where the language is
   irregular — French adds `ordinal_1` for "1er" and nothing else, English
   needs 1, 2, 3, 21, 22, 23 and 31. A language with no ordinals just sets
   `ordinal` to `{1}`. Note the same pattern serves both "on the 1st" and the
   day inside a date, so pick the form that works in both.
4. Do the plural forms hold up? `every_n_minutes`, `every_n_hours` and
   `every_n_days_at_midnight` always receive a number greater than one, so a
   language with several plural forms only needs the one that fits 2 and above.
5. Is `list_separator` right for joining day names (`, ` in most languages,
   `、` in Japanese and Chinese)?
6. Are the month and day names in the right form for appearing inside a date,
   rather than standing alone?

## Known rough edges in the source phrasing

These are awkward in English too, and are inherited from the descriptions the
library has always produced. Translate them literally for now rather than
improving on them, so that all languages stay in step:

* `every_second_at` — "every second (:*/10)" leaks cron syntax into the phrase.
* `minute_past` — "every minute past 7" really means "at 7 minutes past every hour".
* `in_months` — combines badly with `month_day`, e.g. "in 1,7 1st".
* `cron_fallback` — used when no phrasing fits; shows the raw expression.

## Adding a language

1. Copy `i18n/en.json` to `i18n/<code>.json` and translate the values.
2. Run `box task run TranslationDocs` to generate the review sheet.
3. Run `./runtests.sh`. The suite checks every bundle against the base key set
   and asserts that no placeholder is left unfilled in any locale.
