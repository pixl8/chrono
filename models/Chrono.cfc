component displayName="ChronoPort" {

    public string function validateExpression( required string crontabExpression ) {
        try {
            _parseExpression( arguments.crontabExpression );
        } catch ( any e ) {
            return e.message;
        }

        return "";
    }

    public string function getNextRunDate( required string crontabExpression, date lastRun=Now() ) {
        if ( arguments.crontabExpression == "disabled" ) {
            return "";
        }

        var parsed  = _parseExpression( arguments.crontabExpression );
        var nextRun = _findNextRun( parsed, arguments.lastRun );

        return _formatDate( nextRun );
    }

    public string function describeCronTabExression( required string crontabExpression, required string locale ) {
        if ( arguments.crontabExpression == "disabled" ) {
            return "disabled";
        }

        var parsed = _parseExpression( arguments.crontabExpression );

        return _describe( parsed, arguments.locale );
    }

// VALIDATION AND PARSING
    private struct function _parseExpression( required string expression ) {
        var normalized = _normalizeExpression( arguments.expression );
        var parts      = ListToArray( normalized, " " );

        if ( ArrayLen( parts ) != 6 ) {
            throw( type: "ChronoPort.InvalidExpression", message: "Cron expression must have exactly 6 fields (second minute hour dayOfMonth month dayOfWeek)" );
        }

        return {
              raw        : normalized
            , second     : _parseField( parts[1], 0, 59, false, false )
            , minute     : _parseField( parts[2], 0, 59, false, false )
            , hour       : _parseField( parts[3], 0, 23, false, false )
            , dayOfMonth : _parseField( parts[4], 1, 31, true, true )
            , month      : _parseField( parts[5], 1, 12, false, false, _getMonthAliases() )
            , dayOfWeek  : _parseField( parts[6], 1, 7, true, true, _getDayOfWeekAliases() )
        };
    }

    private string function _normalizeExpression( required string expression ) {
        var parts = ListToArray( arguments.expression, " " );

        if ( ArrayLen( parts ) >= 6 ) {
            if ( parts[4] == "*" && parts[6] != "?" ) {
                parts[4] = "?";
            } else if ( parts[4] != "?" ) {
                parts[6] = "?";
            }
        }

        return ArrayToList( parts, " " );
    }

    private array function _parseField(
          required string  field
        , required numeric min
        , required numeric max
        , required boolean allowQuestion
        , required boolean allowSpecial
        ,          struct  aliases = {}
    ) {
        if ( arguments.field == "*" ) {
            return [ { type="all" } ];
        }

        if ( arguments.field == "?" ) {
            if ( !arguments.allowQuestion ) {
                throw( type: "ChronoPort.InvalidExpression", message: "The '?' character is only allowed in day-of-month and day-of-week fields" );
            }
            return [ { type="question" } ];
        }

        if ( arguments.allowSpecial && arguments.field == "L" ) {
            return [ { type="last" } ];
        }

        var constraints = [];

        for ( var segment in ListToArray( arguments.field, "," ) ) {
            segment = Trim( segment );

            if ( arguments.allowSpecial && segment == "L" ) {
                ArrayAppend( constraints, { type="last" } );
                continue;
            }

            if ( arguments.allowSpecial && Find( "##", segment ) ) {
                var hashParts = ListToArray( segment, "##" );
                if ( ArrayLen( hashParts ) == 2 ) {
                    var dayNum = _resolveAlias( hashParts[1], arguments.aliases, arguments.min, arguments.max );
                    var nth    = _resolveAlias( hashParts[2], arguments.aliases, 1, 5 );
                    _validateValue( dayNum, arguments.min, arguments.max );
                    _validateValue( nth, 1, 5 );
                    ArrayAppend( constraints, { type="nth", dayOfWeek=dayNum, nth=nth } );
                    continue;
                }
            }

            if ( arguments.allowSpecial && Right( segment, 1 ) == "W" ) {
                var dayNum = Val( segment );
                _validateValue( dayNum, 1, 31 );
                ArrayAppend( constraints, { type="weekday", nearestTo=dayNum } );
                continue;
            }

            if ( Find( "/", segment ) ) {
                var stepParts = ListToArray( segment, "/" );
                var step      = _resolveAlias( stepParts[2], arguments.aliases, 1, Max( arguments.max, 59 ) );

                if ( stepParts[1] == "*" || stepParts[1] == "" ) {
                    ArrayAppend( constraints, { type="step", from=arguments.min, to=arguments.max, step=step } );
                } else if ( Find( "-", stepParts[1] ) ) {
                    var rangeParts = ListToArray( stepParts[1], "-" );
                    var rangeFrom  = _resolveAlias( rangeParts[1], arguments.aliases, arguments.min, arguments.max );
                    var rangeTo    = _resolveAlias( rangeParts[2], arguments.aliases, arguments.min, arguments.max );
                    _validateValue( rangeFrom, arguments.min, arguments.max );
                    _validateValue( rangeTo, arguments.min, arguments.max );
                    ArrayAppend( constraints, { type="step", from=rangeFrom, to=rangeTo, step=step } );
                } else {
                    var stepFrom = _resolveAlias( stepParts[1], arguments.aliases, arguments.min, arguments.max );
                    _validateValue( stepFrom, arguments.min, arguments.max );
                    ArrayAppend( constraints, { type="step", from=stepFrom, to=arguments.max, step=step } );
                }
                continue;
            }

            if ( Find( "-", segment ) && !Find( "##", segment ) ) {
                var rangeParts = ListToArray( segment, "-" );
                var rangeFrom  = _resolveAlias( rangeParts[1], arguments.aliases, arguments.min, arguments.max );
                var rangeTo    = _resolveAlias( rangeParts[2], arguments.aliases, arguments.min, arguments.max );
                _validateValue( rangeFrom, arguments.min, arguments.max );
                _validateValue( rangeTo, arguments.min, arguments.max );
                ArrayAppend( constraints, { type="range", from=rangeFrom, to=rangeTo } );
                continue;
            }

            var value = _resolveAlias( segment, arguments.aliases, arguments.min, arguments.max );
            _validateValue( value, arguments.min, arguments.max );
            ArrayAppend( constraints, { type="value", value=value } );
        }

        if ( ArrayIsEmpty( constraints ) ) {
            throw( type: "ChronoPort.InvalidExpression", message: "Could not parse field value: #arguments.field#" );
        }

        return constraints;
    }

    private numeric function _resolveAlias( required string token, required struct aliases, required numeric min, required numeric max ) {
        if ( IsNumeric( arguments.token ) ) {
            return Int( arguments.token );
        }

        var upper = UCase( Trim( arguments.token ) );

        if ( StructKeyExists( arguments.aliases, upper ) ) {
            return arguments.aliases[ upper ];
        }

        if ( IsNumeric( arguments.token ) ) {
            return Int( arguments.token );
        }

        throw( type: "ChronoPort.InvalidExpression", message: "Unknown value: [#arguments.token#]" );
    }

    private void function _validateValue( required numeric value, required numeric min, required numeric max ) {
        if ( arguments.value < arguments.min || arguments.value > arguments.max ) {
            throw( type: "ChronoPort.InvalidExpression", message: "Value [#arguments.value#] is out of range [#arguments.min#-#arguments.max#]" );
        }
    }

    private struct function _getMonthAliases() {
        return {
              "JAN" = 1, "FEB" = 2, "MAR" = 3, "APR" = 4, "MAY" = 5, "JUN" = 6
            , "JUL" = 7, "AUG" = 8, "SEP" = 9, "OCT" = 10, "NOV" = 11, "DEC" = 12
        };
    }

    private struct function _getDayOfWeekAliases() {
        return {
              "SUN" = 1, "MON" = 2, "TUE" = 3, "WED" = 4, "THU" = 5, "FRI" = 6, "SAT" = 7
        };
    }

// NEXT RUN CALCULATION
    private date function _findNextRun( required struct parsed, required date fromDate ) {
        var dt = {
              year   = Year( arguments.fromDate )
            , month  = Month( arguments.fromDate )
            , day    = Day( arguments.fromDate )
            , hour   = Hour( arguments.fromDate )
            , minute = Minute( arguments.fromDate )
            , second = Second( arguments.fromDate )
        };

        dt.second++;
        _normalizeDateTime( dt );

        var maxIterations = 525600;

        for ( var i = 0; i < maxIterations; i++ ) {
            var secMatch = _nextMatching( arguments.parsed.second, dt.second, 0, 59, dt.year, dt.month );
            if ( secMatch != dt.second ) {
                if ( secMatch == -1 ) {
                    _advance( dt, "minute" );
                    continue;
                }
                dt.second = secMatch;
            }

            var minMatch = _nextMatching( arguments.parsed.minute, dt.minute, 0, 59, dt.year, dt.month );
            if ( minMatch != dt.minute ) {
                if ( minMatch == -1 ) {
                    _advance( dt, "hour" );
                    continue;
                }
                dt.minute = minMatch;
                dt.second = _minMatching( arguments.parsed.second, 0, 59, dt.year, dt.month );
                continue;
            }

            var hourMatch = _nextMatching( arguments.parsed.hour, dt.hour, 0, 23, dt.year, dt.month );
            if ( hourMatch != dt.hour ) {
                if ( hourMatch == -1 ) {
                    _advance( dt, "day" );
                    continue;
                }
                dt.hour   = hourMatch;
                dt.minute = _minMatching( arguments.parsed.minute, 0, 59, dt.year, dt.month );
                dt.second = _minMatching( arguments.parsed.second, 0, 59, dt.year, dt.month );
                continue;
            }

            if ( !_dayMatches( arguments.parsed, dt.year, dt.month, dt.day ) ) {
                _advance( dt, "day" );
                continue;
            }

            var monthMatch = _nextMatching( arguments.parsed.month, dt.month, 1, 12, dt.year, dt.month );
            if ( monthMatch != dt.month ) {
                if ( monthMatch == -1 ) {
                    _advance( dt, "year" );
                    continue;
                }
                dt.month  = monthMatch;
                dt.day    = 1;
                dt.hour   = _minMatching( arguments.parsed.hour, 0, 23, dt.year, dt.month );
                dt.minute = _minMatching( arguments.parsed.minute, 0, 59, dt.year, dt.month );
                dt.second = _minMatching( arguments.parsed.second, 0, 59, dt.year, dt.month );
                continue;
            }

            return CreateDateTime( dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second );
        }

        throw( type: "ChronoPort.NoMatch", message: "Could not find next run date within 525600 iterations" );
    }

    private boolean function _dayMatches( required struct parsed, required numeric year, required numeric month, required numeric day ) {
        var dom = arguments.parsed.dayOfMonth;
        var dow = arguments.parsed.dayOfWeek;
        var isDomQuestion = ( ArrayLen( dom ) == 1 && dom[1].type == "question" );
        var isDowQuestion = ( ArrayLen( dow ) == 1 && dow[1].type == "question" );

        if ( isDomQuestion && isDowQuestion ) {
            return true;
        }

        if ( isDowQuestion ) {
            return _matchesField( dom, arguments.day, arguments.year, arguments.month );
        }

        if ( isDomQuestion ) {
            var cfDayOfWeek = _cfDayOfWeek( arguments.year, arguments.month, arguments.day );
            return _matchesField( dow, cfDayOfWeek, arguments.year, arguments.month );
        }

        var domMatch = _matchesField( dom, arguments.day, arguments.year, arguments.month );
        var dowMatch = _matchesField( dow, _cfDayOfWeek( arguments.year, arguments.month, arguments.day ), arguments.year, arguments.month );

        return domMatch || dowMatch;
    }

    private boolean function _matchesField(
          required array  constraints
        , required numeric value
        , required numeric year
        , required numeric month
    ) {
        for ( var c in arguments.constraints ) {
            if ( _matchesConstraint( c, arguments.value, arguments.year, arguments.month ) ) {
                return true;
            }
        }
        return false;
    }

    private boolean function _matchesConstraint(
          required struct constraint
        , required numeric value
        , required numeric year
        , required numeric month
    ) {
        switch ( arguments.constraint.type ) {
            case "all":
                return true;

            case "value":
                return arguments.constraint.value == arguments.value;

            case "range":
                return arguments.value >= arguments.constraint.from && arguments.value <= arguments.constraint.to;

            case "step":
                if ( arguments.value < arguments.constraint.from || arguments.value > arguments.constraint.to ) {
                    return false;
                }
                return ( arguments.value - arguments.constraint.from ) % arguments.constraint.step == 0;

            case "last":
                if ( StructKeyExists( arguments.constraint, "dayOfWeek" ) ) {
                    // L in day-of-week - last occurrence of this weekday in the month
                    var dow    = arguments.constraint.dayOfWeek;
                    var dim    = _daysInMonth( arguments.month, arguments.year );
                    var lastDt = CreateDate( arguments.year, arguments.month, dim );
                    var lastD0 = _cfDayOfWeek( arguments.year, arguments.month, dim );

                    var diff = dow - lastD0;
                    if ( diff > 0 ) {
                        diff = diff - 7;
                    }
                    var lastSpecificDay = dim + diff;
                    return arguments.value == lastSpecificDay;
                }
                // L in day-of-month - last day of the month
                return arguments.value == _daysInMonth( arguments.month, arguments.year );

            case "weekday":
                var dim   = _daysInMonth( arguments.month, arguments.year );
                var dt    = arguments.constraint.nearestTo;
                var day0  = _cfDayOfWeek( arguments.year, arguments.month, dt );

                if ( day0 == 1 ) {
                    dt = dt == 1 ? dt + 1 : dt - 1;
                } else if ( day0 == 7 ) {
                    dt = dt == dim ? dt - 2 : dt + 1;
                }

                return arguments.value == dt;

            case "nth":
                var dow       = arguments.constraint.dayOfWeek;
                var nth       = arguments.constraint.nth;
                var dim       = _daysInMonth( arguments.month, arguments.year );
                var firstDow = _cfDayOfWeek( arguments.year, arguments.month, 1 );
                var diff     = dow - firstDow;
                if ( diff < 0 ) {
                    diff += 7;
                }
                var targetDay = 1 + diff + ( ( nth - 1 ) * 7 );
                return arguments.value == targetDay;
        }

        return false;
    }

    private numeric function _nextMatching(
          required array  constraints
        , required numeric current
        , required numeric min
        , required numeric max
        , required numeric year
        , required numeric month
    ) {
        for ( var v = arguments.current; v <= arguments.max; v++ ) {
            if ( _matchesField( arguments.constraints, v, arguments.year, arguments.month ) ) {
                return v;
            }
        }
        return -1;
    }

    private numeric function _minMatching(
          required array  constraints
        , required numeric min
        , required numeric max
        , required numeric year
        , required numeric month
    ) {
        return _nextMatching( arguments.constraints, arguments.min, arguments.min, arguments.max, arguments.year, arguments.month );
    }

    private void function _advance( required struct dt, required string unit ) {
        switch ( arguments.unit ) {
            case "second":
                arguments.dt.second++;
                break;
            case "minute":
                arguments.dt.minute++;
                arguments.dt.second = 0;
                break;
            case "hour":
                arguments.dt.hour++;
                arguments.dt.minute = 0;
                arguments.dt.second = 0;
                break;
            case "day":
                arguments.dt.day++;
                arguments.dt.hour   = 0;
                arguments.dt.minute = 0;
                arguments.dt.second = 0;
                break;
            case "year":
                arguments.dt.year++;
                arguments.dt.month  = 1;
                arguments.dt.day    = 1;
                arguments.dt.hour   = 0;
                arguments.dt.minute = 0;
                arguments.dt.second = 0;
                break;
        }

        _normalizeDateTime( arguments.dt );
    }

    private void function _normalizeDateTime( required struct dt ) {
        while ( arguments.dt.second >= 60 ) { arguments.dt.second -= 60; arguments.dt.minute++; }
        while ( arguments.dt.minute >= 60 ) { arguments.dt.minute -= 60; arguments.dt.hour++; }
        while ( arguments.dt.hour >= 24 ) { arguments.dt.hour -= 24; arguments.dt.day++; }

        while ( arguments.dt.day > _daysInMonth( arguments.dt.month, arguments.dt.year ) ) {
            arguments.dt.day -= _daysInMonth( arguments.dt.month, arguments.dt.year );
            arguments.dt.month++;
            if ( arguments.dt.month > 12 ) {
                arguments.dt.month = 1;
                arguments.dt.year++;
            }
        }

        while ( arguments.dt.month > 12 ) {
            arguments.dt.month -= 12;
            arguments.dt.year++;
        }
    }

    private numeric function _daysInMonth( required numeric month, required numeric year ) {
        return Day( DateAdd( "d", -1, DateAdd( "m", 1, CreateDate( arguments.year, arguments.month, 1 ) ) ) );
    }

    private numeric function _cfDayOfWeek( required numeric year, required numeric month, required numeric day ) {
        return DayOfWeek( CreateDate( arguments.year, arguments.month, arguments.day ) );
    }

// DESCRIPTION
    private string function _describe( required struct parsed, required string locale ) {
        var lang = UCase( ListFirst( arguments.locale, "-" ) );
        var desc = _describeExpression( arguments.parsed );

        return desc;
    }

    private string function _describeExpression( required struct parsed ) {
        var f = arguments.parsed;
        var secAll  = _isAll( f.second );
        var minAll  = _isAll( f.minute );
        var hrAll   = _isAll( f.hour );
        var domAll  = _isAll( f.dayOfMonth ) || _isQuestion( f.dayOfMonth );
        var monAll  = _isAll( f.month );
        var dowAll  = _isAll( f.dayOfWeek ) || _isQuestion( f.dayOfWeek );

        var sec0    = _isValue( f.second, 0 );
        var min0    = _isValue( f.minute, 0 );
        var hr0     = _isValue( f.hour, 0 );

        if ( secAll && minAll && hrAll && domAll && monAll ) {
            return "every second";
        }

        if ( minAll && hrAll && domAll && monAll && dowAll ) {
            if ( sec0 ) { return "every minute"; }
            return "every second (:#_describeField( f.second )#)";
        }

        if ( sec0 && hrAll && domAll && monAll && dowAll ) {
            if ( min0 ) {
                return "every hour";
            }
            if ( _isSpecificInterval( f.minute ) ) {
                return "every #_describeInterval( f.minute )#";
            }
            return "every minute past #_describeMinute( f.minute )#";
        }

        if ( sec0 && min0 && domAll && monAll && dowAll ) {
            if ( _isSpecificInterval( f.hour ) ) {
                return "every #_describeInterval( f.hour )#";
            }
            return "every day at #_describeHourMinute( f.hour, f.minute )#";
        }

        if ( sec0 && min0 && hr0 ) {
            if ( domAll && monAll && !dowAll ) {
                return "every week on #_describeDOWOnly( f.dayOfWeek )# at midnight";
            }
            if ( _isSpecificDay( f.dayOfMonth ) && monAll && dowAll ) {
                return "every month on the #_ordinal( _firstValue( f.dayOfMonth ) )# at midnight";
            }
            if ( !domAll && monAll && dowAll ) {
                if ( _isSpecificInterval( f.dayOfMonth ) ) {
                    return "every #f.dayOfMonth[1].step# days at midnight";
                }
                return "every #_describeField( f.dayOfMonth )# days at midnight";
            }
            if ( domAll && monAll && dowAll ) {
                return "every day at midnight";
            }
            if ( !monAll ) {
                return "every year on #_describeMonthDay( f.month, f.dayOfMonth )# at midnight";
            }
            return "at midnight";
        }

        if ( sec0 && min0 && domAll && monAll && !dowAll ) {
            return "#_describeDOWOnly( f.dayOfWeek )# at #_describeHourMinute( f.hour, f.minute )#";
        }

        return _fallbackDescription( arguments.parsed );
    }

    private string function _describeSecond( required array constraints, boolean prefixSpace=false ) {
        if ( _isAll( arguments.constraints ) ) {
            return "";
        }
        var prefix = arguments.prefixSpace ? " " : "";
        if ( _isValue( constraints, 0 ) ) {
            return "";
        }
        return prefix & "(:#_describeField( constraints )#)";
    }

    private string function _describeField( required array constraints ) {
        if ( ArrayLen( arguments.constraints ) == 1 ) {
            var c = arguments.constraints[1];
            switch ( c.type ) {
                case "value": return c.value;
                case "range": return "#c.from#-#c.to#";
                case "step":
                    if ( c.from == 0 ) {
                        if ( c.to == 59 ) return "*/#c.step#";
                        return "0-#c.to#/#c.step#";
                    }
                    return "#c.from#-#c.to#/#c.step#";
                case "all": return "*";
            }
        }
        var parts = [];
        for ( var c in arguments.constraints ) {
            ArrayAppend( parts, _describeField( [c] ) );
        }
        return ArrayToList( parts, "," );
    }

    private string function _describeInterval( required array constraints ) {
        if ( _isEvery( constraints, 5, 59 ) ) {
            return "5 minutes";
        }
        if ( _isEvery( constraints, 15, 59 ) ) {
            return "15 minutes";
        }
        if ( _isEvery( constraints, 30, 59 ) ) {
            return "30 minutes";
        }
        if ( _isEvery( constraints, 1, 59 ) ) {
            return "minute";
        }
        if ( _isEvery( constraints, 1, 23 ) ) {
            return "hour";
        }
        if ( _isEvery( constraints, 2, 23 ) ) {
            return "2 hours";
        }
        if ( _isEvery( constraints, 3, 23 ) ) {
            return "3 hours";
        }
        if ( _isEvery( constraints, 4, 23 ) ) {
            return "4 hours";
        }
        if ( _isEvery( constraints, 6, 23 ) ) {
            return "6 hours";
        }
        if ( _isEvery( constraints, 8, 23 ) ) {
            return "8 hours";
        }
        if ( _isEvery( constraints, 12, 23 ) ) {
            return "12 hours";
        }
        if ( ArrayLen( constraints ) == 1 && constraints[1].type == "step" ) {
            return "#constraints[1].step# " & _intervalUnit( constraints[1].to );
        }
        return "minute";
    }

    private string function _describeEverySecond( required array constraints ) {
        if ( ArrayLen( constraints ) == 1 && constraints[1].type == "step" ) {
            if ( constraints[1].step == 5 && constraints[1].to == 59 ) return "5 seconds";
            if ( constraints[1].step == 10 && constraints[1].to == 59 ) return "10 seconds";
            if ( constraints[1].step == 15 && constraints[1].to == 59 ) return "15 seconds";
            if ( constraints[1].step == 30 && constraints[1].to == 59 ) return "30 seconds";
        }
        return _describeField( constraints );
    }

    private string function _intervalUnit( required numeric max ) {
        if ( arguments.max <= 59 ) return "minutes";
        if ( arguments.max <= 23 ) return "hours";
        return "";
    }

    private string function _describeMinute( required array constraints ) {
        if ( _isAll( constraints ) ) return "*";
        if ( ArrayLen( constraints ) == 1 && constraints[1].type == "step" ) {
            return "*/#constraints[1].step#";
        }
        return _describeField( constraints );
    }

    private string function _describeHourMinute( required array hour, required array minute ) {
        var h = _firstValue( arguments.hour );
        var m = _firstValue( arguments.minute );
        if ( IsNull( h ) ) {
            return _describeCron( arguments.hour ) & ":" & _pad( _firstValue( arguments.minute ) );
        }
        return _pad( h ) & ":" & _pad( m );
    }

    private string function _describeMonth( required array constraints ) {
        if ( _isAll( arguments.constraints ) || _isQuestion( arguments.constraints ) ) {
            return "every month";
        }
        var vals = _getValues( arguments.constraints );
        if ( ArrayLen( vals ) == 1 ) {
            var monthNames = [ "", "January", "February", "March", "April", "May", "June",
                                  "July", "August", "September", "October", "November", "December" ];
            return monthNames[ vals[1] ];
        }
        return "in " & _describeField( arguments.constraints );
    }

    private string function _describeMonthDay( required array month, required array day ) {
        var m = _describeMonth( arguments.month );
        var d = _firstValue( arguments.day );
        if ( !IsNull( d ) ) {
            return "#m# #_ordinal( d )#";
        }
        return m;
    }

    private string function _describeDOWOnly( required array constraints ) {
        if ( _isAll( arguments.constraints ) || _isQuestion( arguments.constraints ) ) {
            return "every day";
        }
        var vals = _getValues( arguments.constraints );
        if ( ArrayLen( vals ) == 1 ) {
            return _dowName( vals[1] );
        }
        var names = [];
        for ( var v in vals ) {
            ArrayAppend( names, _dowName( v ) );
        }
        return ArrayToList( names, "," );
    }

    private string function _dowName( required numeric dayNum ) {
        var names = [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ];
        return names[ arguments.dayNum ];
    }

    private string function _ordinal( required numeric n ) {
        if ( arguments.n % 100 >= 11 && arguments.n % 100 <= 13 ) {
            return "#arguments.n#th";
        }
        switch ( arguments.n % 10 ) {
            case 1:  return "#arguments.n#st";
            case 2:  return "#arguments.n#nd";
            case 3:  return "#arguments.n#rd";
            default: return "#arguments.n#th";
        }
    }

    private string function _pad( required numeric n ) {
        return NumberFormat( arguments.n, "00" );
    }

    private string function _fallbackDescription( required struct parsed ) {
        var f = arguments.parsed;
        if ( _isAll( f.minute ) && _isAll( f.hour ) ) {
            return "cron(#f.raw#)";
        }
        if ( _isAll( f.dayOfMonth ) || _isQuestion( f.dayOfMonth ) ) {
            if ( _hasSpecificDOW( f.dayOfWeek ) ) {
                return "#_describeDOWOnly( f.dayOfWeek )# at #_describeHourMinute( f.hour, f.minute )#";
            }
        }
        return "cron(#f.raw#)";
    }

    private string function _describeCron( required array constraints ) {
        return _describeField( arguments.constraints );
    }

// FIELD QUERY HELPERS
    private boolean function _isAll( required array constraints ) {
        return ArrayLen( arguments.constraints ) == 1 && arguments.constraints[1].type == "all";
    }

    private boolean function _isQuestion( required array constraints ) {
        return ArrayLen( arguments.constraints ) == 1 && arguments.constraints[1].type == "question";
    }

    private boolean function _isValue( required array constraints, required numeric value ) {
        return ArrayLen( arguments.constraints ) == 1
            && arguments.constraints[1].type == "value"
            && arguments.constraints[1].value == arguments.value;
    }

    private boolean function _isSpecificInterval( required array constraints ) {
        return ArrayLen( arguments.constraints ) == 1 && arguments.constraints[1].type == "step";
    }

    private boolean function _isEvery( required array constraints, required numeric step, required numeric max ) {
        return ArrayLen( arguments.constraints ) == 1
            && arguments.constraints[1].type == "step"
            && arguments.constraints[1].step == arguments.step
            && arguments.constraints[1].from == 0
            && arguments.constraints[1].to == arguments.max;
    }

    private boolean function _isSpecificDay( required array constraints ) {
        if ( _isAll( arguments.constraints ) || _isQuestion( arguments.constraints ) ) {
            return false;
        }
        return ArrayLen( arguments.constraints ) == 1 && arguments.constraints[1].type == "value";
    }

    private boolean function _isSpecificMonth( required array constraints ) {
        if ( _isAll( arguments.constraints ) || _isQuestion( arguments.constraints ) ) {
            return false;
        }
        return ArrayLen( arguments.constraints ) == 1 && arguments.constraints[1].type == "value";
    }

    private boolean function _hasSpecificDOW( required array constraints ) {
        if ( _isAll( arguments.constraints ) || _isQuestion( arguments.constraints ) ) {
            return false;
        }
        return true;
    }

    private numeric function _firstValue( required array constraints ) {
        for ( var c in arguments.constraints ) {
            if ( c.type == "value" ) {
                return c.value;
            }
        }
        return JavaCast( "null", 0 );
    }

    private array function _getValues( required array constraints ) {
        var vals = [];
        for ( var c in arguments.constraints ) {
            switch ( c.type ) {
                case "value":
                    ArrayAppend( vals, c.value );
                    break;
                case "range":
                    for ( var v = c.from; v <= c.to; v++ ) {
                        ArrayAppend( vals, v );
                    }
                    break;
            }
        }
        ArraySort( vals, "numeric" );
        return vals;
    }

// FORMATTING
    private string function _formatDate( required date dt ) {
        return DateFormat( arguments.dt, "yyyy-MM-dd" ) & "T" & TimeFormat( arguments.dt, "HH:mm:ss" );
    }
}
