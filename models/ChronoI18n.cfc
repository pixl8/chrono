/**
 * Translation helper for Chrono's human readable cron descriptions.
 *
 * Descriptions are built from message templates held in `/i18n/<locale>.json`.
 * Each template may contain `{1}`, `{2}`, ... placeholders which are filled in
 * positionally.
 *
 * Locale resolution mirrors the fallback behaviour of Java's ResourceBundle:
 * a request for `pt-BR` is served by merging `en.json` (the base bundle),
 * then `pt.json`, then `pt_BR.json`, so a partial translation degrades to
 * English one string at a time rather than all at once.
 *
 * Month and day-of-week names are held in the bundles too, as `month_1` ...
 * `month_12` and `dow_1` ... `dow_7` (`dow_1` being Sunday, matching Chrono's
 * day-of-week numbering). They are deliberately not read from the engine's own
 * locale data: LSDateFormat() is not available on every CFML engine, and
 * shipping the names as data keeps Chrono's output identical everywhere and
 * puts every visible string in front of the translator.
 *
 */
component displayName="Chrono i18n" {

// CONSTRUCTOR
	/**
	 * @i18nDirectory.hint Directory containing the `<locale>.json` bundles. Defaults to the library's own `/i18n` directory.
	 * @defaultLocale.hint Locale used as the base bundle, and as the fallback for any string a bundle does not translate.
	 */
	public any function init( string i18nDirectory="", string defaultLocale="en" ) {
		variables._i18nDirectory = Len( Trim( arguments.i18nDirectory ) )
		                         ? arguments.i18nDirectory
		                         : GetDirectoryFromPath( GetCurrentTemplatePath() ) & "../i18n/";

		variables._defaultLocale = arguments.defaultLocale;
		variables._files         = {};
		variables._bundles       = {};

		return this;
	}

// PUBLIC API
	/**
	 * Returns the translated message for the given key, with any `{n}`
	 * placeholders replaced by the supplied arguments.
	 *
	 */
	public string function translate( required string key, required string locale, array args=[] ) {
		var bundle  = _getBundle( arguments.locale );
		var message = StructKeyExists( bundle, arguments.key ) ? bundle[ arguments.key ] : arguments.key;

		for( var i=1; i<=ArrayLen( arguments.args ); i++ ) {
			message = Replace( message, "{#i#}", arguments.args[ i ], "all" );
		}

		return message;
	}

	/**
	 * Returns the full month name for the given month number (1-12).
	 *
	 */
	public string function monthName( required numeric month, required string locale ) {
		return translate( "month_#arguments.month#", arguments.locale );
	}

	/**
	 * Returns the full day name for the given day number, where 1 is Sunday
	 * (Chrono's day-of-week numbering).
	 *
	 */
	public string function dayOfWeekName( required numeric dayNum, required string locale ) {
		return translate( "dow_#arguments.dayNum#", arguments.locale );
	}

	/**
	 * Returns the ordinal form of a day of the month, e.g. "3rd" in English,
	 * "3." in German, plain "3" in Russian.
	 *
	 * `ordinal` is the pattern for every day; `ordinal_<n>` overrides a single
	 * day where the language is irregular. Ordinal rules do not transfer between
	 * languages -- English marks 1, 21 and 31 alike, French marks only the 1st --
	 * so an override is looked up in the requested language's own bundles and is
	 * deliberately never inherited from the base bundle.
	 *
	 */
	public string function ordinal( required numeric n, required string locale ) {
		var ownBundle = _getOwnBundle( arguments.locale );
		var key       = "ordinal_#arguments.n#";

		if ( !StructKeyExists( ownBundle, key ) && StructKeyExists( ownBundle, "ordinal" ) ) {
			key = "ordinal";
		}

		return translate( key, arguments.locale, [ arguments.n ] );
	}

	/**
	 * Returns the locale codes for which a bundle file exists. Used by the
	 * test suite and the translation doc generator.
	 *
	 */
	public array function listLocales() {
		var files   = DirectoryList( variables._i18nDirectory, false, "name", "*.json" );
		var locales = [];

		for( var file in files ) {
			ArrayAppend( locales, ReReplaceNoCase( file, "\.json$", "" ) );
		}

		ArraySort( locales, "textnocase" );

		return locales;
	}

	/**
	 * Returns the raw, unmerged contents of a single bundle file.
	 *
	 */
	public struct function getBundleFile( required string locale ) {
		return _readFile( arguments.locale );
	}

	public string function getDefaultLocale() {
		return variables._defaultLocale;
	}

// PRIVATE HELPERS
	private struct function _getBundle( required string locale ) {
		var cacheKey = LCase( Trim( arguments.locale ) );

		if ( !StructKeyExists( variables._bundles, cacheKey ) ) {
			variables._bundles[ cacheKey ] = _buildBundle( arguments.locale );
		}

		return variables._bundles[ cacheKey ];
	}

	/**
	 * The requested locale's own bundles merged together, without the base
	 * bundle underneath. Used for keys that must not be inherited.
	 *
	 */
	private struct function _getOwnBundle( required string locale ) {
		var cacheKey = "own:" & LCase( Trim( arguments.locale ) );

		if ( !StructKeyExists( variables._bundles, cacheKey ) ) {
			var bundle = {};

			for( var candidate in _getCandidates( arguments.locale ) ) {
				StructAppend( bundle, _readFile( candidate ), true );
			}

			variables._bundles[ cacheKey ] = bundle;
		}

		return variables._bundles[ cacheKey ];
	}

	private struct function _buildBundle( required string locale ) {
		var bundle = Duplicate( _readFile( variables._defaultLocale ) );

		for( var candidate in _getCandidates( arguments.locale ) ) {
			StructAppend( bundle, _readFile( candidate ), true );
		}

		return bundle;
	}

	/**
	 * Turns a locale code into the bundle names to look for, least specific
	 * first. "pt-BR" becomes [ "pt", "pt_BR" ].
	 *
	 */
	private array function _getCandidates( required string locale ) {
		var parts = ListToArray( ReReplace( Trim( arguments.locale ), "[-_]", "_", "all" ), "_" );

		if ( !ArrayLen( parts ) ) {
			return [];
		}

		var language   = LCase( parts[ 1 ] );
		var candidates = [ language ];

		if ( ArrayLen( parts ) > 1 && Len( parts[ 2 ] ) ) {
			ArrayAppend( candidates, language & "_" & UCase( parts[ 2 ] ) );
		}

		return candidates;
	}

	private struct function _readFile( required string name ) {
		if ( !StructKeyExists( variables._files, arguments.name ) ) {
			var filePath = variables._i18nDirectory & arguments.name & ".json";
			var contents = {};

			if ( FileExists( filePath ) ) {
				try {
					contents = DeserializeJson( FileRead( filePath, "utf-8" ) );
				} catch( any e ) {
					throw(
						  type    = "Chrono.InvalidBundle"
						, message = "The Chrono translation bundle [#arguments.name#.json] could not be parsed: #e.message#"
					);
				}
			}

			variables._files[ arguments.name ] = IsStruct( contents ) ? contents : {};
		}

		return variables._files[ arguments.name ];
	}


}
