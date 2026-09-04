# Third-party notices

Chrono itself is MIT licensed — see [LICENCE.txt](LICENCE.txt). This file records
the third-party work Chrono derives from, and the terms that work carries.

## cron-utils

Chrono is a CFML port of **cron-utils**.

* Project: https://github.com/jmrozanec/cron-utils
* Copyright 2014 jmrozanec and the cron-utils contributors
* Licensed under the Apache License, Version 2.0
* Licence text: [licences/cron-utils-LICENSE.txt](licences/cron-utils-LICENSE.txt)
  (also at http://www.apache.org/licenses/LICENSE-2.0)

Chrono was written against cron-utils 9.2.1. It ships no cron-utils source
code, byte code or resource files, and carries no Java, JAR or OSGi dependency
on it. What is derived is the *design*: the
Quartz-flavoured six-field parsing rules, the next-execution search, and the
set of cases the human-readable descriptions recognise were all worked out by
reading the cron-utils source, so this repository is best treated as a
derivative work and attributed accordingly.

### Significant changes from cron-utils

Noted here to satisfy section 4(b) of the Apache License, and because the
differences are large enough to matter to anyone expecting cron-utils' output:

* Reimplemented in CFML with no Java, JAR or OSGi dependency, so it runs on any
  CFML engine rather than requiring a JVM.
* Only the Quartz six-field format is supported. cron-utils' other cron
  flavours, its builder, converters, mappers and validation annotations have no
  equivalent here.
* Descriptions are generated differently and do not match cron-utils'
  word for word. cron-utils translates roughly two dozen short phrase atoms and
  concatenates them in an order fixed by Java; Chrono selects one whole message
  template per recognised expression shape, so each language controls its own
  word order. See [TRANSLATIONS.md](TRANSLATIONS.md).
* The translation bundles in `/i18n` are original work. They share no message
  keys, no placeholder syntax and no translated strings with cron-utils'
  `CronUtilsI18N*.properties` resource bundles. Chrono also covers a different
  set of phrases, because it translates whole sentences rather than atoms.
* Month and day names, and day-of-month ordinals, are shipped as bundle data
  rather than read from `java.util.Locale`, so output is identical on every
  CFML engine.

## Unicode CLDR

The initial month and day-of-week names in the `/i18n` bundles (the `month_1` …
`month_12` and `dow_1` … `dow_7` keys) were seeded from the Unicode Common
Locale Data Repository, by way of the locale data built into the JVM, and
adjusted by hand where a language needs a different form in this context — for
example Chinese, which uses numeric month names rather than the CLDR wide
names.

* Project: https://cldr.unicode.org
* Copyright © 1991-present Unicode, Inc.
* Distributed under the Unicode License: https://www.unicode.org/license.txt
