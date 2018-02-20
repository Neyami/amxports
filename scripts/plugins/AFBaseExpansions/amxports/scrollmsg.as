/*****************************************************************************************
* AMXX Scrolling Message, by AMXX Dev Team
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXScrollmsg amxscrollmsg;

void AMXScrollmsg_Call()
{
	amxscrollmsg.RegisterExpansion( amxscrollmsg );
}

class AMXScrollmsg : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMXX Ports: Scrolling Message " + AMXScrollmsg::VERSION;
		this.ShortName = "AMXSM";
	}

	void ExpansionInit()
	{
		RegisterCommand( "amx_scrollmsg", "!s", "Text and frequency in seconds of scrolling message.", AFBase::ACCESS_C, @AMXScrollmsg::PluginSettings );
		// .amx_scrollmsg "Welcome to §hostname§ -- This server is using AFBase 600"
		// as_command .amx-scrollmsg "Welcome to §hostname§ -- This server is using AFBase 600"

		@AMXScrollmsg::cvar_sTimeDisplay = CCVar( "amx-scrollmsg", "Welcome to §hostname§ -- This server is using AFBase 600", "Text and frequency in seconds of scrolling message.", ConCommandFlag::AdminOnly ); 
	}

	void MapInit()
	{
		if( !AMXScrollmsg::cvar_sTimeDisplay.GetString().IsEmpty() )
			AMXScrollmsg::setMessageFunction( AMXScrollmsg::cvar_sTimeDisplay.GetString() );
	}

	void StopEvent()
	{
		if( AMXScrollmsg::m_pScrollMsgInitThink !is null )
		{
			g_Scheduler.RemoveTimer( AMXScrollmsg::m_pScrollMsgInitThink );
			@AMXScrollmsg::m_pScrollMsgInitThink = null;
		}

		if( AMXScrollmsg::m_pScrollMsgThink !is null )
		{
			g_Scheduler.RemoveTimer( AMXScrollmsg::m_pScrollMsgThink );
			@AMXScrollmsg::m_pScrollMsgThink = null;
		}
	}

	void StartEvent()
	{
		if( !AMXScrollmsg::cvar_sTimeDisplay.GetString().IsEmpty() )
			AMXScrollmsg::setMessageFunction( AMXScrollmsg::cvar_sTimeDisplay.GetString() );
	}
}

namespace AMXScrollmsg
{
	const string VERSION = "1.0";

	CScheduledFunction@ m_pScrollMsgThink = null;
	CScheduledFunction@ m_pScrollMsgInitThink = null;
	CCVar@ cvar_sTimeDisplay;
	const float SPEED = 0.3f;

	int g_iStartPos, g_iEndPos, g_iLength, g_iFrequency;
	string g_sScrollMsg, g_sDisplayMsg;
	float g_xPos;

	const string MIN_FREQ = "Minimal frequency for this message is %1 seconds\n";
	const string MSG_FREQ = "Scrolling message displaying frequency: %1\n";
	const string MSG_DISABLED = "Scrolling message disabled\n";

	void showMsg()
	{
		int a = g_iStartPos, i = 0;
		g_sDisplayMsg = "";

		while( a < g_iEndPos )
			//g_sDisplayMsg.SubString(i++, 1) = g_sScrollMsg.SubString(a++, 1);
			g_sDisplayMsg += g_sScrollMsg.opIndex(a++);

		//g_Game.AlertMessage( at_console, "[[[[[SCROLLMSG DEBUG]]]]]\ng_sScrollMsg: %1\ng_sDisplayMsg: %2\n", g_sScrollMsg, g_sDisplayMsg );
		//g_sDisplayMsg.SubString(i, 1) = "";

		if( g_iEndPos < g_iLength )
			g_iEndPos++;

		if( g_xPos > 0.35f )
			g_xPos -= 0.0063f;
		else
		{
			g_iStartPos++;
			g_xPos = 0.35f;
		}

		HUDTextParams textParms = amxports.set_hudmessage( 200, 100, 0, g_xPos, 0.90f, 0, SPEED, SPEED, 0.05f, 0.05f, 2 );
		amxports.show_hudmessage( 0, g_sDisplayMsg, textParms );
	}

	void msgInit()
	{
		g_iEndPos = 1;
		g_iStartPos = 0;
		g_xPos = 0.65f;

		string hostname = g_EngineFuncs.CVarGetString( "hostname" );
		g_sScrollMsg.Replace( "§hostname§", hostname );

		g_iLength = g_sScrollMsg.Length();

		@m_pScrollMsgThink = g_Scheduler.SetInterval( "showMsg", SPEED, g_iLength + 48 );

		g_PlayerFuncs.ClientPrintAll( HUD_PRINTCONSOLE, string(g_sScrollMsg) + "\n" );
	}

	void setMessageFunction( string args )
	{
		if( m_pScrollMsgInitThink !is null )
		{
			g_Scheduler.RemoveTimer( m_pScrollMsgInitThink );
			@m_pScrollMsgInitThink = null;
		}

		if( m_pScrollMsgThink !is null )
		{
			g_Scheduler.RemoveTimer( m_pScrollMsgThink );
			@m_pScrollMsgThink = null;
		}

		array<string> parsed = args.Split(" ");

		string buffer = "";
		for( uint i = 0; i < parsed.length() - 1; ++i )
		{
			if( i > 0 ) buffer += " ";

			buffer += parsed[i];
		}
		g_sScrollMsg = buffer;

		g_iLength = g_sScrollMsg.Length();

		g_iFrequency = atoi( parsed[parsed.length()-1] );

		//g_Game.AlertMessage( at_console, "[[[[[SCROLLMSG DEBUG]]]]]\ng_sScrollMsg: %1\ng_iLength: %2\ng_iFrequency: %3\n", g_sScrollMsg, g_iLength, g_iFrequency );

		if( g_iFrequency > 0 )
		{
			int minimal = int(Math.Floor(((g_iLength + 48) * (SPEED + 0.1f)) + 0.5f));
			//g_Game.AlertMessage( at_console, "[[[[[SCROLLMSG DEBUG]]]]]\nminimal: %1\n", minimal );

			if( g_iFrequency < minimal )
			{
				string msg;
				snprintf( msg, MIN_FREQ, minimal );
				amxscrollmsg.Log( msg );
				g_iFrequency = minimal;
			}

			string msg;
			string timetext = amxports.setTimeText(g_iFrequency);
			snprintf( msg, MSG_FREQ, timetext );
			amxscrollmsg.Log( msg );

			@m_pScrollMsgInitThink = g_Scheduler.SetInterval( "msgInit", float(g_iFrequency), g_Scheduler.REPEAT_INFINITE_TIMES );
		}
		else
			amxscrollmsg.Log( MSG_DISABLED );
	}

	void PluginSettings( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( pPlayer is null )
		{
			amxscrollmsg.Log( "PluginSettings: pPlayer is null!\n" );
			return;
		}

		const string sCommand = args.RawArgs[0];

		if( args.GetCount() < 1 )//If no args are supplied
		{
			if( sCommand == "amx_scrollmsg" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_scrollmsg\" is \"" + cvar_sTimeDisplay.GetString() + "\"\n" );
		}
		else if( args.GetCount() == 1 )//If one arg is supplied (value to set)
		{
			array<string> rawargs = args.GetString(0).Split(" ");

			if( !g_Utility.IsStringInt(rawargs[rawargs.length()-1]) )
			{
				amxscrollmsg.Tell( "Last \"arg\" needs to be the delay in seconds!", pPlayer, HUD_PRINTCONSOLE );
				return;
			}

			rawargs = args.RawArgs;
			string buffer = "";
			for( uint i = 1; i < rawargs.length(); ++i )
			{
				if( i > 1 ) buffer += " ";

				buffer += rawargs[i];
			}

			if( buffer != cvar_sTimeDisplay.GetString() )
			{
				cvar_sTimeDisplay.SetString(buffer);

				setMessageFunction( args.GetString(0) );

				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_scrollmsg\" changed to \"" + cvar_sTimeDisplay.GetString() + "\"\n" );
			}
		}
	}
}

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		January 11 2018
*	-------------------------
*	- First release
*	-------------------------
*/
