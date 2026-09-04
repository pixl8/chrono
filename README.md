# Chrono

Pure CFML library for working with Quartz-style (6-field) cron expressions:
validation, next-run-date calculation and human-readable descriptions. A
dependency-free port of [cron-utils](https://github.com/jmrozanec/cron-utils)
with no Java / JAR / OSGi requirement, so it runs on any CFML engine.

## Usage

```cfscript
// coldbox
chrono = getModel( "chrono@chrono" ); // or inject as property, etc.

// without coldbox
chrono = new chrono.models.Chrono();

chrono.validateExpression( "0 */5 * * * *" );            // "" (valid)
chrono.getNextRunDate( "0 0 0 * * *", Now() );           // "2026-07-09T00:00:00"
chrono.describeCronTabExression( "0 0 0 * * *", "en" );  // "every day at 00:00"
chrono.describeCronTabExression( "0 0 0 * * *", "fr" );  // "chaque jour à 00:00"
```

## Descriptions and languages

`describeCronTabExression()` takes a locale and ships with 17 languages: English,
Dutch, French, German, Greek, Indonesian, Italian, Japanese, Korean, Polish,
Portuguese, Romanian, Russian, Spanish, Swahili, Turkish and Chinese
(Simplified).

Both `fr` and `fr-FR` / `fr_FR` are accepted, resolved from least to most
specific, and anything a language has not translated falls back to English one
string at a time. Descriptions are built from whole message templates rather
than assembled word by word, so each language controls its own word order.

Month names, day names and ordinals are shipped as data rather than read from the
engine, so a cron is described identically on every CFML engine.

See [TRANSLATIONS.md](TRANSLATIONS.md) to review a language or add one.

## Cron format

Quartz 6-field format: `second minute hour dayOfMonth month dayOfWeek`

```
0 0 12 ? * MON-FRI
| | |  | |    |
| | |  | |    +-- Day of Week (1-7 or SUN-SAT)
| | |  | +------- Month (1-12 or JAN-DEC)
| | |  +--------- Day of Month (1-31)
| | +------------ Hour (0-23)
| +-------------- Minute (0-59)
+---------------- Second (0-59)
```

| Character | Meaning | Applicable Fields |
|-----------|---------|-------------------|
| `*` | All values | All |
| `?` | No specific value | Day of month, day of week |
| `-` | Range (e.g., `1-5`) | All |
| `,` | List (e.g., `1,3,5`) | All |
| `/` | Increment (e.g., `*/5`) | All |
| `L` | Last | Day of month, day of week |
| `W` | Nearest weekday | Day of month |
| `#` | Nth weekday (e.g., `3#2`) | Day of week |

## Code of conduct

Participation in this project is governed by the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Attribution

Chrono is a CFML port of [cron-utils](https://github.com/jmrozanec/cron-utils)
(Copyright 2014 jmrozanec, Apache License 2.0). It ships none of that project's
code, but the parsing rules, next-run search and the set of cases the
descriptions recognise are derived from it.

See [NOTICE.md](NOTICE.md) for the full third-party notices, the Apache 2.0
licence text and a list of the significant differences from cron-utils.

## Licence

MIT — see [LICENCE.txt](LICENCE.txt).
