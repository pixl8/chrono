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
chrono.describeCronTabExression( "0 0 0 * * *", "en" );  // "every day at midnight"
```

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

## Licence

MIT — see [LICENSE.txt](LICENSE.txt).
