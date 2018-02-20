/*****************************************************************************************
* AMXX timeleft, by AMXX Dev Team
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXTimeLeft amxtimeleft;

void AMXTimeLeft_Call()
{
	amxtimeleft.RegisterExpansion( amxtimeleft );
}

class AMXTimeLeft : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMXX Ports: Timeleft " + AMXTimeLeft::VERSION;
		this.ShortName = "AMXTL";
	}

	void ExpansionInit()
	{
		RegisterCommand( "amx_time_display", "!si", "Sets flags for remaining time display.", AFBase::ACCESS_G, @AMXTimeLeft::PluginSettings );
		// Displaying of time remaining
		// a - display white text on bottom
		// b - use voice
		// c - don't add "remaining" (only in voice)
		// d - don't add "hours/minutes/seconds" (only in voice)
		// e - show/speak if current time is less than this set in parameter
		//
		// Default value: "ab 1200" "ab 600" "ab 300" "ab 180" "ab 60" "bcde 11"
		// .amx_time_display "ab 1200 ab 600 ab 300 ab 180 ab 60 bcde 11"
		// as_command .amx-time-display "ab 1200 ab 600 ab 300 ab 180 ab 60 bcde 11"
		RegisterCommand( "amx_time_voice", "!i", "Sets whether to announce \"say thetime\" and \"say timeleft\" with voice. (default: 1)", AFBase::ACCESS_G, @AMXTimeLeft::PluginSettings ); 

		RegisterCommand( "say thetime", "", "- displays current time", AFBase::ACCESS_Z, @AMXTimeLeft::sayTheTime, false, false );
		RegisterCommand( "say timeleft", "", "- displays timeleft", AFBase::ACCESS_Z, @AMXTimeLeft::sayTimeLeft, false, false );

		@AMXTimeLeft::g_iTimeVoice = CCVar( "amx-time-voice", 1, "Spoken time-announcements 0/1 (default: 1)", ConCommandFlag::AdminOnly ); 
		@AMXTimeLeft::g_sTimeDisplay = CCVar( "amx-time-display", "ab 1200 ab 600 ab 300 ab 180 ab 60 bcde 11", "Displaying of time remaining", ConCommandFlag::AdminOnly ); 

		@AMXTimeLeft::m_pTimeRemainThink = g_Scheduler.SetInterval( "timeRemain", 0.8f, g_Scheduler.REPEAT_INFINITE_TIMES );
	}

	void MapInit()
	{
		if( !AMXTimeLeft::g_sTimeDisplay.GetString().IsEmpty() )
			AMXTimeLeft::setDisplayingFunction( AMXTimeLeft::g_sTimeDisplay.GetString().Split(" ") );
	}

	void StopEvent()
	{
		if( AMXTimeLeft::m_pTimeRemainThink !is null )
		{
			g_Scheduler.RemoveTimer( AMXTimeLeft::m_pTimeRemainThink );
			@AMXTimeLeft::m_pTimeRemainThink = null;
		}
	}

	void StartEvent()
	{
		if( AMXTimeLeft::m_pTimeRemainThink is null )
			@AMXTimeLeft::m_pTimeRemainThink = g_Scheduler.SetInterval( "timeRemain", 0.8f, g_Scheduler.REPEAT_INFINITE_TIMES );
	}
}

namespace AMXTimeLeft
{
	const string VERSION = "1.0";

	CScheduledFunction@ m_pTimeRemainThink = null;
	CCVar@ g_iTimeVoice;
	CCVar@ g_sTimeDisplay;
	array<Vector2D>g_TimeSet(32);
	int g_iSwitch, g_iCountDown, g_iLastTime;

	void sayTheTime( AFBaseArguments@ args )
	{
		if( g_iTimeVoice.GetInt() == 1 )
		{
			string mhours, mmins, whours, wmins, wpm;

			mhours = amxports.get_time("%H");
			mmins = amxports.get_time("%M");

			int mins = atoi(mmins);
			int hrs = atoi(mhours);

			if( mins > 0 )
				wmins = amxports.num_to_word(mins);
			else
				wmins = "";

			if( hrs < 12 )
				wpm = "am ";
			else
			{
				if( hrs > 12 ) hrs -= 12;
				wpm = "pm ";
			}

			if( hrs > 0 )
				whours = amxports.num_to_word(hrs);
			else
				whours = "twelve ";

			amxports.speak("fvox/time_is_now " + whours + wmins + wpm );
		}

		string ctime;

		ctime = amxports.get_time("%m/%d/%Y - %H:%M:%S");
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "The time:   " + ctime + "\n" );
	}

	void sayTimeLeft( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		if( pPlayer is null ) return;

		if( g_EngineFuncs.CVarGetFloat("mp_timelimit") > 0 )
		{
			int a = amxports.get_timeleft();

			if( g_iTimeVoice.GetInt() == 1 )
			{
				string sVoice = setTimeVoice(0, a);
				amxports.speak(sVoice);
			}

			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "Time Left:  " + (a / 60) + ":" + (a % 60) + "\n" );
		}
		else
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "No Time Limit\n" );
	}

	string setTimeVoice( int iFlags, int iTimeLeft )
	{
		array<string> temp(7);
		int secs = iTimeLeft % 60;
		int mins = iTimeLeft / 60;

		/*for( int a = 0; a < 7; ++a )
			temp[a] = "";*/

		if( secs > 0 )
		{
			temp[4] = amxports.num_to_word(secs);

			if( (iFlags & 8) != 1 ) //d - don't add "hours/minutes/seconds" (only in voice)
				temp[5] = (secs > 1) ? "seconds " : "seconds(e84) ";
		}

		if( mins > 59 )
		{
			int hours = mins / 60;

			temp[0] = amxports.num_to_word(hours);

			if( (iFlags & 8) != 1 ) //d - don't add "hours/minutes/seconds" (only in voice)
				temp[1] = (hours > 1) ? "hours " : "hours(e70) ";

			mins = mins % 60;
		}

		if( mins > 0 )
		{
			temp[2] = amxports.num_to_word(mins);

			if( (iFlags & 8) != 1 ) //d - don't add "hours/minutes/seconds" (only in voice)
				temp[3] = (mins > 1) ? "minutes " : "minutes(e64) ";
		}

		if( (iFlags & 4) != 1 ) //c - don't add "remaining" (only in voice)
			temp[6] = "remaining ";

		return "vox/" + temp[0] + temp[1] + temp[2] + temp[3] + temp[4] + temp[5] + temp[6];
	}

	int findDispFormat( int time )
	{
		for( uint i = 0; i< g_TimeSet.length(); ++i )
		{
			int iFlags = int(g_TimeSet[i].x);
			int iTime = int(g_TimeSet[i].y);

			if( (iFlags & 16) != 0 ) //e - show/speak if current time is less than this set in parameter
			{
				if( iTime > time )
				{
					if( g_iSwitch == 0 )
					{
						g_iCountDown = g_iSwitch = time;

						if( AMXTimeLeft::m_pTimeRemainThink !is null )
						{
							g_Scheduler.RemoveTimer( AMXTimeLeft::m_pTimeRemainThink );
							@AMXTimeLeft::m_pTimeRemainThink = null;
						}

						@m_pTimeRemainThink = g_Scheduler.SetInterval( "timeRemain", 1.0f, g_Scheduler.REPEAT_INFINITE_TIMES );
					}

					return i;
				}
			}
			else if( iTime == time )
				return i;
		}

		return -1;
	}

	void setDisplayingFunction( array<string> args )
	{
		for( uint i = 0; i < (args.length() - 1) and i < 32; i+=2 )
		{
			g_TimeSet[i].x = amxports.read_flags(args[i]);
			g_TimeSet[i].y = atoi(args[i+1]);
		}
	}

	void timeRemain()
	{
		int gmtm = amxports.get_timeleft();
		int tmlf = (g_iSwitch > 0) ? --g_iCountDown : gmtm;

		if( g_iSwitch > 0 and gmtm > g_iSwitch )
		{
			if( AMXTimeLeft::m_pTimeRemainThink !is null )
			{
				g_Scheduler.RemoveTimer( AMXTimeLeft::m_pTimeRemainThink );
				@AMXTimeLeft::m_pTimeRemainThink = null;
			}

			g_iSwitch = 0;
			@m_pTimeRemainThink = g_Scheduler.SetInterval( "timeRemain", 0.8f, g_Scheduler.REPEAT_INFINITE_TIMES );

			return;
		}

		if( tmlf > 0 and g_iLastTime != tmlf )
		{
			g_iLastTime = tmlf;
			int tm_set = findDispFormat(tmlf);

			if( tm_set != -1 )
			{
				int flags = int(g_TimeSet[tm_set].x);
				string arg;

				if( (flags & 1) != 0 ) //a - display white text on bottom
				{
					HUDTextParams textParms;
					arg = amxports.setTimeText(tmlf);

					if( (flags & 16) != 0 )
						textParms = amxports.set_hudmessage( 255, 255, 255, -1.0f, 0.85f, 0, 0.0f, 1.1f, 0.1f, 0.5f, -1 );
					else
						textParms = amxports.set_hudmessage( 255, 255, 255, -1.0f, 0.85f, 0, 0.0f, 3.0f, 0.0f, 0.5f, -1 );

					amxports.show_hudmessage(0, arg, textParms);
				}

				if( (flags & 2) != 0) //b - use voice
				{
					arg = setTimeVoice(flags, tmlf);
					amxports.speak(arg);
				}
			}
		}
	}

	void PluginSettings( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( pPlayer is null )
		{
			amxtimeleft.Log( "PluginSettings: pPlayer is null!\n" );
			return;
		}

		const string sCommand = args.RawArgs[0];

		if( args.GetCount() < 1 )//If no args are supplied
		{
			if( sCommand == "amx_time_voice" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_time_voice\" is \"" + g_iTimeVoice.GetInt() + "\"\n" );
			else if( sCommand == "amx_time_display" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_time_display\" is \"" + g_sTimeDisplay.GetString() + "\"\n" );
		}
		else if( args.GetCount() == 1 )//If one arg is supplied (value to set)
		{
			if( sCommand == "amx_time_voice" and Math.clamp(0, 1, args.GetInt(0)) != g_iTimeVoice.GetInt() )
			{
				g_iTimeVoice.SetInt( Math.clamp(0, 1, args.GetInt(0)) );
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_time_voice\" changed to \"" + g_iTimeVoice.GetInt() + "\"\n" );
			}
			else if( sCommand == "amx_time_display" )
			{
				array<string> rawargs = args.RawArgs;

				string buffer = "";
				for( uint i = 1; i < rawargs.length(); ++i )
				{
					if( i > 1 ) buffer += " ";

					buffer += rawargs[i];
				}

				if( buffer != g_sTimeDisplay.GetString() )
				{
					g_sTimeDisplay.SetString(buffer);

					rawargs.removeAt(0);
					setDisplayingFunction(rawargs);

					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_time_display\" changed to \"" + g_sTimeDisplay.GetString() + "\"\n" );
				}
			}
		}
	}
}

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		January 09 2018
*	-------------------------
*	- First release
*	-------------------------
*/
