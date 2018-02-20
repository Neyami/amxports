AMXPorts amxports;

void AMXPorts_Call()
{
	amxports.RegisterExpansion( amxports );
}

class AMXPorts : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMXX Ports";
		this.ShortName = "AMXP";
	}

	void ExpansionInit()
	{
		RegisterCommand( "admin_show_activity", "!i", "1: hide admin name, 2: show admin name, 3: show name only to admins, hide to normal players. (default: 1)", AFBase::ACCESS_C, @AMXPorts::PluginSettings );
		@AMXPorts::cvar_iAdminShowActivity = CCVar( "admin-show-activity", 1, "1: hide admin name, 2: show admin name, 3: show name only to admins, hide to normal players. (default: 1)", ConCommandFlag::AdminOnly );
	}

	int contain( string sSource, string sString )
	{
		uint uiTemp = sSource.Find(sString);

		if( uiTemp != Math.SIZE_MAX )
			return int(uiTemp);

		return -1;
	}

	int containi( string sSource, string sString )
	{
		uint uiTemp = sSource.ToLowercase().Find(sString.ToLowercase());

		if( uiTemp != Math.SIZE_MAX )
			return int(uiTemp);

		return -1;
	}

	int get_timeleft()
	{
		float flCvarTimeLimit = g_EngineFuncs.CVarGetFloat("mp_timelimit");

		if( flCvarTimeLimit > 0 )
		{
			int iReturn = int((flCvarTimeLimit * 60.0f) - g_Engine.time);
			return (iReturn < 0) ? 0 : iReturn;
		}

		return 0;
	}

	string num_to_word( int value )
	{
		const array<string> words = 
			{"zero ","one ","two ","three ","four ",
			"five ", "six ","seven ","eight ","nine ","ten ",
			"eleven ","twelve ","thirteen ","fourteen ","fifteen ",
			"sixteen ","seventeen ","eighteen ","nineteen ",
			"twenty ","thirty ","fourty ", "fifty ","sixty ",
			"seventy ","eighty ","ninety ",
			"hundred ","thousand "};

		string output = "";
		if( value < 0 ) value = -value;
		int tho = value / 1000;
		int aaa = 0;

		if( tho > 0 )
		{
			output += words[tho];
			output += words[29];
			value = value % 1000;
		}

		int hun = value / 100;

		if( hun > 0 )
		{
			output += words[hun];
			output += words[28];
			value = value % 100;
		}

		int ten = value / 10;
		int unit = value % 10;

		if( ten > 0 )
			output += words[(ten > 1) ? (ten + 18) : (unit + 10)];
		
		if( ten != 1 and (unit > 0 or (value < 1 and hun < 1 and tho < 1))) 
			output += words[unit];

		return output;
	}

	string get_time( const string &in sFormat )
	{
		DateTime datetime;
		string sDateTime;
		datetime.Format(sDateTime,sFormat);

		return sDateTime;
	}

	string setTimeText( int iTimeLeft )
	{
		string text = "";
		int secs = iTimeLeft % 60;
		int mins = iTimeLeft / 60;

		if( secs == 0 )
			text = string(mins) + " " + ((mins > 1) ? "minutes" : "minute");
		else if( mins == 0 )
			text = string(secs) + " " + ((secs > 1) ? "seconds" : "second");
		else
			text = string(mins) + " " + ((mins > 1) ? "minutes" : "minute") + " " + secs + " " + ((secs > 1) ? "seconds" : "second");

		return text;
	}

	HUDTextParams set_hudmessage( uint8 red = 200, uint8 green = 100, uint8 blue = 0, float x = -1.0f, float y = 0.35f, int effect = 0, float fxtime = 6.0f, float holdtime = 12.0f, float fadeintime = 0.1f, float fadeouttime = 0.2f, int channel = -1 )
	{
		HUDTextParams textParms;
		textParms.r1 = Math.clamp( 0, 255, red );
		textParms.g1 = Math.clamp( 0, 255, green );
		textParms.b1 = Math.clamp( 0, 255, blue );
		textParms.x = Math.clamp( -1, 1.0f, x );
		textParms.y = Math.clamp( -1, 1.0f, y );
		textParms.effect = Math.clamp( 0, 2, effect );
		textParms.fxTime = fxtime;
		textParms.holdTime = holdtime;
		textParms.fadeinTime = fadeintime;
		textParms.fadeoutTime = fadeouttime;
		textParms.channel = Math.clamp( 1, 4, channel );

		return textParms;
	}

	void show_hudmessage( const int &in id, string sMessage, HUDTextParams textParms )
	{
		if( id == 0 )
			g_PlayerFuncs.HudMessageAll( textParms, sMessage ); 
		else
		{
			if( id < 1 or id > g_Engine.maxClients )
			{
				amxports.Log( "Invalid player id in show_hudmessage " + id );

				return;
			}

			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);

			if( pPlayer !is null and pPlayer.IsConnected() )
				g_PlayerFuncs.HudMessage( pPlayer, textParms, sMessage );
		}
	}

	void speak( string _text )
	{
		if( _text.IsEmpty() ) _text = "error";

		dictionary keys;
		keys["origin"] = "0 0 0";
		keys["_text"] = _text;

		CBaseEntity@ speaker = g_EntityFuncs.CreateEntity( "env_sentence", keys, true );
		speaker.Use( null, null, USE_TOGGLE, 0 );
		g_EntityFuncs.Remove(speaker);
	}

	void client_cmd( const int &in id, string _text )
	{
		if( _text.IsEmpty() )
		{
			amxports.Log( "Command string is empty" );
			return;
		}

        string cmd = _text;
        array<string> parsed = cmd.Split(" ");

		if( parsed.length() > 1 and parsed[0] != "mp3" )
		{
			cmd = parsed[0] + " \"";
			for( uint i = 1; i < parsed.length; i++ )
			{
				if( i > 1 ) cmd += " ";
				cmd += parsed[i];
			}

			cmd += "\"";
		}
		else cmd = _text;

		if( id == 0 )
		{
			for( int i = 1; i <= g_Engine.maxClients; ++i )
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
				if( pPlayer !is null and pPlayer.IsConnected() )
				{
					amxports.Log( "Ran command [" + cmd + "] on player " + pPlayer.pev.netname );
					NetworkMessage message( MSG_ONE, NetworkMessages::NetworkMessageType(9), pPlayer.edict() ); //SVC_STUFFTEXT
						message.WriteString(cmd);
					message.End();
				}
			}
		}
		else
		{
			if( id < 1 or id > g_Engine.maxClients )
			{
				amxports.Log( "Invalid player id " + id );
				return;
			}

			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
			if( pPlayer !is null and pPlayer.IsConnected() )
			{
				amxports.Log( "Ran command [" + cmd + "] on player " + pPlayer.pev.netname );
				NetworkMessage message( MSG_ONE, NetworkMessages::NetworkMessageType(9), pPlayer.edict() ); //SVC_STUFFTEXT
					message.WriteString(cmd);
				message.End();
			}
		}
	}

	void server_cmd( const string &in cmd )
	{
		g_EngineFuncs.ServerCommand(cmd + "\n");
	}

	int read_flags( const string &in input )
	{
		int flags = 0;
		const string flagstring = "abcdefghijklmnopqrstuvwxyz";

		for( uint i = 0; i < input.Length(); ++i )
		{
			int buffer = containi( flagstring, input.SubString(i, 1) );
			if( buffer != -1 ) flags |= (1<<(buffer));
		}

		return flags;
	}

	void set_user_rendering( const int &in id, int fx = kRenderFxNone, int r = 0, int g = 0, int b = 0, int render = kRenderNormal, int amount = 0 )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
		if( pPlayer is null )
		{
			amxports.Log( "pPlayer is null in set_user_rendering( " + id + ", " + fx + ", " + r + ", " + g + ", " + b + ", " + render + ", " + amount + " )\n" );
			return;
		}

		pPlayer.pev.renderfx = fx;
		pPlayer.pev.rendercolor = Vector(r, g, b);
		pPlayer.pev.rendermode = render;
		pPlayer.pev.renderamt = amount;
	}

	void set_rendering( CBaseEntity@ entity, int fx = kRenderFxNone, int r = 255, int g = 255, int b = 255, int render = kRenderNormal, int amount = 16 )
	{
		if( entity is null )
		{
			amxports.Log( "entity is null in set_rendering( entity, " + fx + ", " + r + ", " + g + ", " + b + ", " + render + ", " + amount + " )\n" );
			return;
		}

		Vector RenderColor;
		RenderColor.x = float(r);
		RenderColor.y = float(g);
		RenderColor.z = float(b);

		entity.pev.renderfx = fx;
		entity.pev.rendercolor = RenderColor;
		entity.pev.rendermode = render;
		entity.pev.renderamt = float(amount);
	}

	CBaseEntity@ find_ent_by_owner( const int &in iEnt, string sClassname, const int &in oEnt, int iCategory = 0 )
	{
		CBaseEntity@ pEnt = null;
		edict_t@ entOwner = null;

		if( iEnt >= 0 )
			@pEnt = g_EntityFuncs.Instance(iEnt); 

		@entOwner = g_EntityFuncs.IndexEnt(oEnt);
		//optional fourth parameter is for jghg2 compatibility
		string sCategory = "";
		switch( iCategory )
		{
			case 1: sCategory = "target"; break;
			case 2: sCategory = "targetname"; break;
			default: sCategory = "classname";
		}

		while( (@pEnt = g_EntityFuncs.FindEntityByString(pEnt, sCategory, sClassname)) != null )
		{
			if( pEnt is null )
				break;
			else if( pEnt.pev.owner is entOwner )
				return pEnt;
		}

		return pEnt;
	}

	CBaseEntity@ find_ent_by_class( const int &in iEnt, string classname )
	{
		CBaseEntity@ pEnt = null;

		if( iEnt >= 0 )
			@pEnt = g_EntityFuncs.Instance(iEnt); 

		@pEnt = g_EntityFuncs.FindEntityByString( pEnt, "classname", classname );

		if( pEnt is null )
			return null;

		return pEnt;
	}

	void remove_entity_name( const string &in eName )
	{
		CBaseEntity@ pEntity = find_ent_by_class( -1, eName );

		while( pEntity !is null )
		{
			g_EntityFuncs.Remove(pEntity);
			@pEntity = find_ent_by_class( -1, eName );
		}
	}

	/*******************************************************
	What type of origin to retrieve:
	  0 - current position
	  1 - position of eyes (and weapon)
	  2 - aim end position from client position
	  3 - aim end position from eyes (hit point for weapon)
	*******************************************************/
	void get_user_origin( int _index, Vector &out origin, int mode = 0 )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( _index );

		if( pPlayer is null )
		{
			amxports.Log( "pPlayer is null in get_user_origin( " + _index + ", origin, " + mode + " )\n" );
			return;
		}

		Vector pos = pPlayer.pev.origin;

		switch( mode )
		{
			case 0: pos = pPlayer.pev.origin; //current position
			case 1: pos = pos + pPlayer.pev.view_ofs; break;
			case 2:
			{
				TraceResult tr;
				Math.MakeVectors( pPlayer.pev.v_angle );
				g_Utility.TraceLine( pos, pos + g_Engine.v_forward * 9999, ignore_monsters, pPlayer.edict(), tr );
				pos = (tr.flFraction < 1.0f) ? tr.vecEndPos : g_vecZero;
				break;
			}
			case 3:
			{
				pos = pos + pPlayer.pev.view_ofs;
				TraceResult tr;
				Math.MakeVectors( pPlayer.pev.v_angle );
				g_Utility.TraceLine( pos, pos + g_Engine.v_forward * 9999, ignore_monsters, pPlayer.edict(), tr );
				pos = (tr.flFraction < 1.0f) ? tr.vecEndPos : g_vecZero;
				break;
			}
		}

		origin = pos;
	}

	void velocity_by_aim( const int &in id, const float &in flVelocity, Vector &out vecOut )
	{
		CBaseEntity@ pEnt = null;

		if( id != -1 ) @pEnt = g_EntityFuncs.Instance(id);

		if( pEnt is null )
		{
			amxports.Log( "pEnt is null in velocity_by_aim!\n");
			return;
		}

		g_EngineFuncs.MakeVectors(pEnt.pev.v_angle);
		Vector vecTemp = g_Engine.v_forward * flVelocity;

		vecOut = vecTemp;
	}

	void menu_destroy( CTextMenu@ mMenu )
	{
		if( mMenu !is null )
		{
			mMenu.Unregister();
			@mMenu = null;
		}
	}

	void show_activity_id( CBasePlayer@ pTarget, CBasePlayer@ pAdmin, const string msg )
	{
		const string name = pAdmin.pev.netname;

		if( pTarget is null || !pTarget.IsConnected() )
			return;

		string prefix;
		if( g_PlayerFuncs.AdminLevel(pAdmin) > ADMIN_NO )
			prefix = "ADMIN";
		else
			prefix = "PLAYER";

		switch( AMXPorts::cvar_iAdminShowActivity.GetInt() )
		{
			case 1: // hide name to all
			{
				g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTNOTIFY, prefix + ": " + msg + "\n" );
				break;
			}

			case 2: // show name to all
			{
				g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTNOTIFY, prefix + " " + name + ": " + msg + "\n" );
				break;
			}

			case 3: // show name only to admins, hide name from normal users
			{
				if( g_PlayerFuncs.AdminLevel(pAdmin) > ADMIN_NO )
					g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTNOTIFY, prefix + " " + name + ": " + msg + "\n" );
				else
					g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTNOTIFY, prefix + ": " + msg + "\n" );

				break;
			}

			case 4: // show name only to admins, show nothing to normal users
			{
				if( g_PlayerFuncs.AdminLevel(pAdmin) > ADMIN_NO )
					g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTNOTIFY, prefix + " " + name + ": " + msg + "\n" );

				break;
			}

			case 5: // hide name only to admins, show nothing to normal users
			{
				if( g_PlayerFuncs.AdminLevel(pAdmin) > ADMIN_NO )
					g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTNOTIFY, prefix + ": " + msg + "\n" );
			}
		}
	}

	/*
	List of filtering flags:
	"a" 1 - match with name
	"b" 2 - match with name substring
	"c" 4 - match with authid
	"d" 8 - match with ip
	"e" 16 - match with team name
	"f" 32 - do not include dead clients
	"g" 64 - do not include alive clients
	"h" 128 - do not include bots
	"i" 256 - do not include human clients
	"j" 512 - return last matched client instead of the first
	"k" 1024 - match with userid
	"l" 2048 - match case insensitively
	"m" 4096 - include connecting clients
	*/
	int find_player( const string &in sFlags, string match )
	{
		bool bCaseSensitive;
		int ilen, userid = 0;
		int flags = read_flags(sFlags);
		string sptemp;

		if( (flags & 31) != 0 )
			sptemp = match;
		else if( (flags & 1024) != 0 )
			userid = atoi(match);

		// a b c d e f g h i j k l
		int result = 0;

		// Switch for the l flag
		if( (flags & 2048) != 0 )
			bCaseSensitive = true;
		else
			bCaseSensitive = false;

		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

			if( pPlayer !is null )
			{
				//"f" 32 - do not include dead clients
				//"g" 64 - do not include alive clients
				if( (pPlayer.IsAlive() ? (flags & 64) != 0 : (flags & 32) != 0) )
					continue;

				//"h" 128 - do not include bots
				//"i" 256 - do not include human clients
				//if (pPlayer->IsBot() ? (flags & 128) : (flags & 256))
					//continue;

				if( (flags & 1) != 0 ) //"a" 1 - match with name
				{
					if( bCaseSensitive )
					{
						if( pPlayer.pev.netname == sptemp )
							continue;
					}
					else if( string(pPlayer.pev.netname).ToLowercase() == sptemp.ToLowercase() )
						continue;

					/*if ((func)(pPlayer->name.c_str(), sptemp))
						continue;*/
				}

				if( (flags & 2) != 0 ) //"b" 2 - match with name substring
				{
					if( bCaseSensitive )
					{
						if( contain(pPlayer.pev.netname, sptemp) == -1 )
							continue;
					}
					else if( containi(pPlayer.pev.netname, sptemp) == -1 )
						continue;
				}

				if( (flags & 4) != 0 ) //"c" 4 - match with authid
				{
					string authid = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );

					if( authid.IsEmpty() or (bCaseSensitive ? authid == sptemp : authid.ToLowercase() == sptemp.ToLowercase()) )
						continue;
				}

				if( (flags & 1024) != 0 ) //"k" 1024 - match with userid
				{
					if( userid != pPlayer.entindex() )
						continue;
				}

				/*if( (flags & 8) != 0 ) //"d" 8 - match with ip
				{
					if (strncmp(pPlayer->ip.c_str(), sptemp, ilen))
						continue;
				}*/
				
				/*if( (flags & 16) != 0 ) //"e" 16 - match with team name
				{
					if ((func)(pPlayer->team.c_str(), sptemp))
						continue;
				}*/

				result = i;

				if( (flags & 512) == 0 ) //"j" 512 - return last matched client instead of the first
					break;
			}
		}

		return result;
	}

	bool is_user_bot( const int &in index )
	{
		if( index < 1 or index > g_Engine.maxClients )
			return false;

		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(index);

		if( pPlayer !is null )
		{
			if( (pPlayer.pev.flags & FL_FAKECLIENT) != 0 )
				return true;

			const string auth = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer)); 

			if( !auth.IsEmpty() and auth == "BOT" )
				return true;
		}

		return false;
	}

	bool file_exists( const string &in sFile )
	{
		File@ file = g_FileSystem.OpenFile( sFile, OpenFile::READ );

		if( file is null or !file.IsOpen() ) return false;

		file.Close();
		return true;
	}
}

namespace AMXPorts
{
	CCVar@ cvar_iAdminShowActivity;

	void PluginSettings( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( pPlayer is null )
		{
			amxports.Log( "PluginSettings: pPlayer is null!\n" );
			return;
		}

		const string sCommand = args.RawArgs[0];

		if( args.GetCount() < 1 )//If no args are supplied
		{
			if( sCommand == "admin_show_activity" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"admin_show_activity\" is \"" + cvar_iAdminShowActivity.GetInt() + "\"\n" );
		}
		else if( args.GetCount() == 1 )//If one arg is supplied (value to set)
		{
			if( sCommand == "admin_show_activity" )
			{
				if( args.GetInt(0) != cvar_iAdminShowActivity.GetInt() )
				{
					cvar_iAdminShowActivity.SetInt( args.GetInt(0) );
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"admin_show_activity\" changed to \"" + cvar_iAdminShowActivity.GetInt() + "\"\n" );
				}
			}
		}
	}
}
