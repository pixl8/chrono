<cfscript>
	reporter = url.reporter ?: "simple";

	testbox = new testbox.system.TestBox( directory={
		  recurse = true
		, mapping = "tests.specs"
	} );

	results = Trim( testbox.run( reporter=reporter ) );

	content reset=true;
	echo( results );
	abort;
</cfscript>
