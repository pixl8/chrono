component extends="testbox.system.BaseSpec" {

	function beforeAll() {
		chrono = new chrono.models.Chrono();
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

			it( "should return a non-empty description regardless of the requested locale", function() {
				expect( Len( chrono.describeCronTabExression( "0 0 0 * * *", "fr-FR" ) ) ).toBeGT( 0 );
			} );

		} );

	}

}
