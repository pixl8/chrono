component extends="testbox.system.BaseSpec" {

	function beforeAll() {
		chrono = new chrono.models.Chrono();
		i18n   = new chrono.models.ChronoI18n();
	}

	function run() {

		describe( "validateExpression()", function() {

			it( "should return an empty string for a valid 6-field expression", function() {
				expect( chrono.validateExpression( "0 0 0 * * *" ) ).toBe( "" );
			} );

			it( "should accept step, range and list values", function() {
				expect( chrono.validateExpression( "0 */5 * * * *"   ) ).toBe( "" );
				expect( chrono.validateExpression( "0 0 9-17 * * *"  ) ).toBe( "" );
				expect( chrono.validateExpression( "0 0 0 1,15 * *"  ) ).toBe( "" );
			} );

			it( "should accept named month and day-of-week aliases", function() {
				expect( chrono.validateExpression( "0 0 12 ? * MON-FRI" ) ).toBe( "" );
				expect( chrono.validateExpression( "0 0 0 1 JAN *"      ) ).toBe( "" );
			} );

			it( "should accept the special L, W and ## characters", function() {
				expect( chrono.validateExpression( "0 0 0 L * ?"    ) ).toBe( "" );
				expect( chrono.validateExpression( "0 0 0 15W * ?"  ) ).toBe( "" );
				expect( chrono.validateExpression( "0 0 0 ? * 6##3"  ) ).toBe( "" );
			} );

			it( "should return an error when the expression does not have exactly 6 fields", function() {
				expect( chrono.validateExpression( "0 0 0 * *" ) ).notToBe( "" );
			} );

			it( "should return an error when a value is out of range", function() {
				expect( chrono.validateExpression( "0 0 99 * * *" ) ).notToBe( "" );
			} );

			it( "should return an error for an unknown alias", function() {
				expect( chrono.validateExpression( "0 0 0 1 NOPE *" ) ).notToBe( "" );
			} );

			it( "should return an error when '?' is used outside day-of-month / day-of-week", function() {
				expect( chrono.validateExpression( "? 0 0 * * *" ) ).notToBe( "" );
			} );

		} );

		describe( "getNextRunDate()", function() {

			it( "should return an empty string when the expression is 'disabled'", function() {
				expect( chrono.getNextRunDate( "disabled", Now() ) ).toBe( "" );
			} );

			it( "should return the next run in yyyy-MM-ddTHH:mm:ss format", function() {
				var result = chrono.getNextRunDate( "0 0 0 * * *", CreateDateTime( 2026, 6, 17, 10, 30, 0 ) );

				expect( result ).toMatch( "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$" );
			} );

			it( "should roll to midnight the following day for a daily-at-midnight expression", function() {
				var result = chrono.getNextRunDate( "0 0 0 * * *", CreateDateTime( 2026, 6, 17, 10, 30, 0 ) );

				expect( result ).toBe( "2026-06-18T00:00:00" );
			} );

			it( "should find the next 5-minute boundary", function() {
				var result = chrono.getNextRunDate( "0 */5 * * * *", CreateDateTime( 2026, 6, 17, 10, 31, 0 ) );

				expect( result ).toBe( "2026-06-17T10:35:00" );
			} );

			it( "should find the next noon for a daily-at-noon expression", function() {
				var result = chrono.getNextRunDate( "0 0 12 * * ?", CreateDateTime( 2026, 6, 17, 13, 0, 0 ) );

				expect( result ).toBe( "2026-06-18T12:00:00" );
			} );

			it( "should honour a specific day-of-month", function() {
				var result = chrono.getNextRunDate( "0 0 0 1 * ?", CreateDateTime( 2026, 6, 17, 0, 0, 0 ) );

				expect( result ).toBe( "2026-07-01T00:00:00" );
			} );

			it( "should honour a specific day-of-week (next Monday)", function() {
				// 2026-06-17 is a Wednesday; next Monday is 2026-06-22
				var result = chrono.getNextRunDate( "0 0 0 ? * MON", CreateDateTime( 2026, 6, 17, 0, 0, 0 ) );

				expect( result ).toBe( "2026-06-22T00:00:00" );
			} );

			it( "should roll over the year boundary", function() {
				var result = chrono.getNextRunDate( "0 0 0 1 1 ?", CreateDateTime( 2026, 6, 17, 0, 0, 0 ) );

				expect( result ).toBe( "2027-01-01T00:00:00" );
			} );

		} );

		describe( "describeCronTabExression()", function() {

			it( "should return 'disabled' when the expression is 'disabled'", function() {
				expect( chrono.describeCronTabExression( "disabled", "en" ) ).toBe( "disabled" );
			} );

			it( "should describe a daily-at-midnight expression", function() {
				expect( chrono.describeCronTabExression( "0 0 0 * * *", "en" ) ).toBe( "every day at 00:00" );
			} );

			it( "should describe an every-minute expression", function() {
				expect( chrono.describeCronTabExression( "0 * * * * *", "en" ) ).toBe( "every minute" );
			} );

			it( "should describe an every-hour expression", function() {
				expect( chrono.describeCronTabExression( "0 0 * * * *", "en" ) ).toBe( "every hour" );
			} );

			it( "should describe an every-5-minutes expression", function() {
				expect( chrono.describeCronTabExression( "0 */5 * * * *", "en" ) ).toBe( "every 5 minutes" );
			} );

			it( "should describe a daily-at-noon expression", function() {
				expect( chrono.describeCronTabExression( "0 0 12 * * ?", "en" ) ).toBe( "every day at 12:00" );
			} );

			it( "should describe an every-5-hours expression", function() {
				expect( chrono.describeCronTabExression( "0 0 */5 * * *", "en" ) ).toBe( "every 5 hours" );
			} );

			it( "should describe a weekly expression", function() {
				expect( chrono.describeCronTabExression( "0 0 0 ? * MON", "en" ) ).toBe( "every week on Monday at midnight" );
			} );

			it( "should describe a monthly expression", function() {
				expect( chrono.describeCronTabExression( "0 0 0 1 * ?", "en" ) ).toBe( "every month on the 1st at midnight" );
			} );

			it( "should describe a yearly expression", function() {
				expect( chrono.describeCronTabExression( "0 0 0 1 1 ?", "en" ) ).toBe( "every year on January 1st at midnight" );
			} );

			it( "should describe a day-of-week-at-time expression", function() {
				expect( chrono.describeCronTabExression( "0 30 9 ? * FRI", "en" ) ).toBe( "Friday at 09:30" );
			} );

		} );

		describe( "describeCronTabExression() localisation", function() {

			it( "should describe expressions in French", function() {
				expect( chrono.describeCronTabExression( "0 0 0 * * *"  , "fr" ) ).toBe( "chaque jour à 00:00" );
				expect( chrono.describeCronTabExression( "0 */15 * * * *", "fr" ) ).toBe( "toutes les 15 minutes" );
				expect( chrono.describeCronTabExression( "0 0 0 ? * MON", "fr" ) ).toBe( "chaque semaine le lundi à minuit" );
			} );

			it( "should describe expressions in German", function() {
				expect( chrono.describeCronTabExression( "0 0 0 * * *"  , "de" ) ).toBe( "täglich um 00:00" );
				expect( chrono.describeCronTabExression( "0 0 * * * *"  , "de" ) ).toBe( "jede Stunde" );
				expect( chrono.describeCronTabExression( "0 0 0 ? * MON", "de" ) ).toBe( "jede Woche am Montag um Mitternacht" );
			} );

			it( "should localise the 'disabled' label", function() {
				expect( chrono.describeCronTabExression( "disabled", "de" ) ).toBe( "deaktiviert" );
			} );

			it( "should localise month names and day-of-month ordinals", function() {
				expect( chrono.describeCronTabExression( "0 0 0 1 1 ?", "fr" ) ).toBe( "chaque année le 1er janvier à minuit" );
				expect( chrono.describeCronTabExression( "0 0 0 3 3 ?", "de" ) ).toBe( "jedes Jahr am 3. März um Mitternacht" );
			} );

			it( "should accept a region-qualified locale", function() {
				expect( chrono.describeCronTabExression( "0 0 0 * * *", "fr-FR" ) ).toBe( chrono.describeCronTabExression( "0 0 0 * * *", "fr" ) );
				expect( chrono.describeCronTabExression( "0 0 0 * * *", "fr_FR" ) ).toBe( chrono.describeCronTabExression( "0 0 0 * * *", "fr" ) );
			} );

			it( "should fall back to English for a locale with no bundle", function() {
				expect( chrono.describeCronTabExression( "0 0 0 * * *", "xx" ) ).toBe( "every day at 00:00" );
			} );

			it( "should fall back for an unknown region-qualified locale", function() {
				expect( Len( chrono.describeCronTabExression( "0 0 0 1 1 ?", "zz-ZZ" ) ) ).toBeGT( 0 );
			} );

			it( "should return a description for every shipped locale", function() {
				for( var locale in i18n.listLocales() ) {
					expect( Len( Trim( chrono.describeCronTabExression( "0 0 0 1 1 ?", locale ) ) ) ).toBeGT( 0, "Empty description for locale [#locale#]" );
				}
			} );

		} );

		describe( "translation bundles", function() {

			it( "should define every key from the base bundle in every locale", function() {
				var baseKeys = StructKeyArray( i18n.getBundleFile( i18n.getDefaultLocale() ) );

				for( var locale in i18n.listLocales() ) {
					var bundle = i18n.getBundleFile( locale );

					for( var key in baseKeys ) {
						// per-day ordinal overrides are language specific by design
						if ( ReFind( "^ordinal_[0-9]+$", key ) ) {
							continue;
						}

						expect( StructKeyExists( bundle, key ) ).toBeTrue( "Locale [#locale#] is missing the key [#key#]" );
					}
				}
			} );

			it( "should not inherit English ordinal rules into other languages", function() {
				// English marks the 21st, French marks only the 1st
				expect( chrono.describeCronTabExression( "0 0 0 21 * ?", "en" ) ).toBe( "every month on the 21st at midnight" );
				expect( chrono.describeCronTabExression( "0 0 0 21 * ?", "fr" ) ).toBe( "chaque mois le 21 à minuit" );
				expect( chrono.describeCronTabExression( "0 0 0 1 * ?" , "fr" ) ).toBe( "chaque mois le 1er à minuit" );
			} );

			it( "should not leave any placeholder unfilled", function() {
				var expressions = [ "0 0 0 * * *", "0 */15 * * * *", "0 0 */6 * * *", "0 0 0 ? * MON", "0 0 0 1 * ?", "0 0 0 1 1 ?", "0 30 9 ? * FRI" ];

				for( var locale in i18n.listLocales() ) {
					for( var expression in expressions ) {
						var description = chrono.describeCronTabExression( expression, locale );

						expect( ReFind( "\{[0-9]\}", description ) ).toBe( 0, "Unfilled placeholder in [#locale#] description of [#expression#]: #description#" );
					}
				}
			} );

		} );

	}

}
