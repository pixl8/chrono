component {
	this.name = "chronoTestSuite" & Hash( GetCurrentTemplatePath() );

	variables.testsDir    = GetDirectoryFromPath( GetCurrentTemplatePath() );
	variables.packageRoot = variables.testsDir & "../";

	this.mappings[ "/chrono"  ] = variables.packageRoot;       // so `new chrono.ChronoPort()` resolves
	this.mappings[ "/tests"   ] = variables.testsDir;          // so testbox can find `tests.specs`
	this.mappings[ "/testbox" ] = variables.testsDir & "testbox";
}
