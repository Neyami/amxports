/*****************************************************************************************
* AMXX Info. Messages, by AMXX Dev Team
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXInfomsgs amxinfomsgs;

void AMXInfomsgs_Call()
{
	amxinfomsgs.RegisterExpansion( amxinfomsgs );
}

class AMXInfomsgs : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMXX Ports: Info. Messages " + AMXInfomsgs::VERSION;
		this.ShortName = "AMXIM";
	}

	void ExpansionInit()
	{
		RegisterCommand( "amx_imessage", "s", "Center typed colored messages (last parameter is a color in RRRGGGBBB format)", AFBase::ACCESS_C, @AMXInfomsgs::setMessage );
		RegisterCommand( "amx_freq_imessage", "!f", "Frequency in seconds of colored messages (default: 180)", AFBase::ACCESS_C, @AMXInfomsgs::PluginSettings );
		// .amx_freq_imessage 180
		// as_command .amx-freq-imessage 180

		@AMXInfomsgs::cvar_flFreqImessage = CCVar( "amx-freq-imessage", 180.0f, "Frequency in seconds of colored messages (default: 180)", ConCommandFlag::AdminOnly ); 
	}

	void MapInit()
	{
		if( AMXInfomsgs::m_pInfoMsgThink !is null )
		{
			g_Scheduler.RemoveTimer( AMXInfomsgs::m_pInfoMsgThink );
			@AMXInfomsgs::m_pInfoMsgThink = null;
		}

		AMXInfomsgs::Restart();

		if( AMXInfomsgs::g_Messages.length() > 0 )
			@AMXInfomsgs::m_pInfoMsgThink = g_Scheduler.SetTimeout( "infoMessage", AMXInfomsgs::cvar_flFreqImessage.GetFloat() );
	}

	void StopEvent()
	{
		if( AMXInfomsgs::m_pInfoMsgThink !is null )
		{
			g_Scheduler.RemoveTimer( AMXInfomsgs::m_pInfoMsgThink );
			@AMXInfomsgs::m_pInfoMsgThink = null;
		}

		AMXInfomsgs::g_iMessagesNum = 0;
		AMXInfomsgs::g_Colors.resize(0);
		AMXInfomsgs::g_Messages.resize(0);
	}

	void StartEvent()
	{
		AMXInfomsgs::Restart();

		if( AMXInfomsgs::g_Messages.length() > 0 )
			@AMXInfomsgs::m_pInfoMsgThink = g_Scheduler.SetTimeout( "infoMessage", AMXInfomsgs::cvar_flFreqImessage.GetFloat() );
	}
}

namespace AMXInfomsgs
{
	const string VERSION	= "1.0";
	const float X_POS		= -1.0f;
	const float Y_POS		= 0.20f;
	const float HOLD_TIME	= 12.0f;
	array<Vector> g_Colors;
	array<string> g_Messages;
	int g_iMessagesNum;
	int g_iCurrent;

	CScheduledFunction@ m_pInfoMsgThink = null;
	CCVar@ cvar_flFreqImessage;

	void setMessage( AFBaseArguments@ args )
	{
		if( m_pInfoMsgThink !is null )
		{
			g_Scheduler.RemoveTimer( m_pInfoMsgThink );
			@m_pInfoMsgThink = null;
		}

		parseMessage( args.GetString(0) );

		float freq_im = cvar_flFreqImessage.GetFloat();

		if( freq_im > 0 ) @m_pInfoMsgThink = g_Scheduler.SetTimeout( "infoMessage", freq_im );
	}

	void parseMessage( const string &in arg )
	{
		array<string> parsed = arg.Split(" ");

		string message = "";
		for( uint i = 0; i < parsed.length() - 1; ++i )
		{
			if( i > 0 ) message += " ";

			message += parsed[i];
		}

		message.Replace( "^n", "\n" );
		string mycol = parsed[parsed.length()-1];
		Vector vals( atof(mycol.SubString(0, 3)), atof(mycol.SubString(3, 3)), atof(mycol.SubString(6, 3)) );

		g_iMessagesNum++;

		g_Messages.insertLast(message);
		g_Colors.insertLast(vals);
	}

	void infoMessage()
	{
		if( g_iCurrent >= g_iMessagesNum )
			g_iCurrent = 0;

		// No messages, just get out of here
		if( g_iMessagesNum == 0 )
			return;

		Vector color;
		string message;

		message = g_Messages[g_iCurrent];
		color = g_Colors[g_iCurrent];

		string hostname = g_EngineFuncs.CVarGetString( "hostname" );
		message.Replace( "§hostname§", hostname );

		HUDTextParams textParms = amxports.set_hudmessage( int(color.x), int(color.y), int(color.z), X_POS, Y_POS, 0, 0.5f, HOLD_TIME, 2.0f, 2.0f, -1 );

		amxports.show_hudmessage( 0, message, textParms );

		g_PlayerFuncs.ClientPrintAll( HUD_PRINTCONSOLE, string(message) + "\n" );
		++g_iCurrent;

		float freq_im = cvar_flFreqImessage.GetFloat();

		if( freq_im > 0 ) @m_pInfoMsgThink = g_Scheduler.SetTimeout( "infoMessage", freq_im );
	}

	void ReadMessages()
	{
		File@ file = g_FileSystem.OpenFile( "scripts/plugins/AFBaseExpansions/amxports/configs/imessage.txt", OpenFile::READ );

		if( file !is null and file.IsOpen() )
		{
			while( !file.EOFReached() )
			{
				string sLine;
				file.ReadLine( sLine );

				if( sLine.SubString(sLine.Length()-1,1) == " " or sLine.SubString(sLine.Length()-1,1) == "\n" or sLine.SubString(sLine.Length()-1,1) == "\r" or sLine.SubString(sLine.Length()-1,1) == "\t" )
						sLine = sLine.SubString( 0, sLine.Length()-1 );

				if( sLine.SubString(0,1) == "#" or sLine.IsEmpty() )
					continue;

				parseMessage( sLine );
			}

			file.Close();
		}
	}

	void Restart()
	{
		g_iMessagesNum = 0;
		g_Colors.resize(0);
		g_Messages.resize(0);
		ReadMessages();
	}

	void PluginSettings( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( pPlayer is null )
		{
			amxinfomsgs.Log( "PluginSettings: pPlayer is null!\n" );
			return;
		}

		if( args.GetCount() < 1 )//If no args are supplied
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_freq_imessage\" is \"" + cvar_flFreqImessage.GetFloat() + "\"\n" );
		else if( args.GetCount() == 1 and args.GetFloat(0) != cvar_flFreqImessage.GetFloat() )//If one arg is supplied (value to set)
		{
			cvar_flFreqImessage.SetFloat( args.GetFloat(0) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_freq_imessage\" changed to \"" + cvar_flFreqImessage.GetFloat() + "\"\n" );

			if( m_pInfoMsgThink !is null )
			{
				g_Scheduler.RemoveTimer( m_pInfoMsgThink );
				@m_pInfoMsgThink = null;
			}

			float freq_im = cvar_flFreqImessage.GetFloat();

			if( freq_im > 0 ) @m_pInfoMsgThink = g_Scheduler.SetTimeout( "infoMessage", freq_im );
		}
	}
}

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		January 28 2018
*	-------------------------
*	- First release
*	-------------------------
*
*	Version: 	1.0-R2
*	Date: 		January 30 2018
*	-------------------------
*	- Fixed recursive function causing spam or something idk the lingo 😂
*	-------------------------
*/
