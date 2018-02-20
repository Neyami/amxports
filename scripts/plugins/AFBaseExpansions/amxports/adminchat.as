/*****************************************************************************************
* AMXX Admin Chat Commands, by AMXX Dev Team
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXAdminChat amxadminchat;

void AMXAdminChat_Call()
{
	amxadminchat.RegisterExpansion( amxadminchat );
}

class AMXAdminChat : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMX Admin Chat Commands " + AMXAdminChat::VERSION;
		this.ShortName = "AMXACC";
	}

	void ExpansionInit()
	{
		//RegisterCommand( "admin_say", "s", "\"(message)\" - sends message to all players", AFBase::ACCESS_H, @AMXAdminChat::cmdSay );
		RegisterCommand( "admin_chat", "s", "\"(message)\" - sends message to admins", AFBase::ACCESS_H, @AMXAdminChat::cmdChat );
		RegisterCommand( "admin_psay", "ss", "(target) \"(message)\" - sends private message", AFBase::ACCESS_H, @AMXAdminChat::cmdPsay );
		RegisterCommand( "admin_tsay", "ss", "(color) \"(message)\" - sends left side hud message to all players", AFBase::ACCESS_H, @AMXAdminChat::cmdTsay );
		RegisterCommand( "admin_csay", "ss", "(color) \"(message)\" - sends center hud message to all players", AFBase::ACCESS_H, @AMXAdminChat::cmdCsay );

		g_Hooks.RegisterHook( Hooks::Player::ClientSay, @AMXAdminChat::ClientSay );
		//RegisterCommand( "say @", "s", "@ <r|g|b|y|m|c|o>(text) - displays hud message", AFBase::ACCESS_G, @NerosFunStuff::PlayerInfiniteAmmo, false, true );
	}
}

namespace AMXAdminChat
{
/*
"@[@|@|@][r|g|b|y|m|c|o]<text> - displays hud message"
The number of @ sets the position
@ = left side of the screen
@@ = center, mid-top
@@@ = center, mid-bottom
r = red
g = green
b = blue
y = yellow
m = magenta
c = cyan
o = orange
example:
@@@othis message will be displayed in the center, mid-bottom in orange
*/
	const string VERSION	= "1.0";
	const uint MAX_CLR = 10;
	uint g_msgChannel;

	const array<string> g_Colors =
	{
		"white",
		"red",
		"green",
		"blue",
		"yellow",
		"magenta",
		"cyan",
		"orange",
		"ocean",
		"maroon"
	};

	const array<Vector> g_Values =
	{
		Vector(255, 255, 255),//white
		Vector(255, 0, 0),//red
		Vector(0, 255, 0),//green
		Vector(0, 0, 255),//blue
		Vector(255, 255, 0),//yellow
		Vector(255, 0, 255),//magenta
		Vector(0, 255, 255),//cyan
		Vector(227, 96, 8),//orange
		Vector(45, 89, 116),//ocean
		Vector(103, 44, 38)//maroon
	};

	const array<Vector2D> g_Pos =
	{
		Vector2D(0.0f, 0.0f),
		Vector2D(0.05f, 0.55f),
		Vector2D(-1.0f, 0.2f),
		Vector2D(-1.0f, 0.7f)
	};

	HookReturnCode ClientSay( SayParameters@ pParams )
	{
		CBasePlayer@ pUser = pParams.GetPlayer();
		string message = pParams.GetCommand();

		if( message.IsEmpty() )
			return HOOK_CONTINUE;

		if( pParams.GetSayType() == CLIENTSAY_SAY )
		{
			if( message.SubString(0, 1) == "@" )
			{
				if( g_PlayerFuncs.AdminLevel(pUser) < ADMIN_YES )
					return HOOK_CONTINUE;

				pParams.ShouldHide = true;
				uint i = 0;

				while( message.SubString(i, 1) == "@" )
				{
					i++;

					if( i > 3 ) break;
				}

				if( i == 0 || i > 3 )
					return HOOK_CONTINUE;

				uint a = 0;

				if( message.SubString(i, 1) == "r" ) a = 1;
				else if( message.SubString(i, 1) == "g" ) a = 2;
				else if( message.SubString(i, 1) == "b" ) a = 3;
				else if( message.SubString(i, 1) == "y" ) a = 4;
				else if( message.SubString(i, 1) == "m" ) a = 5;
				else if( message.SubString(i, 1) == "c" ) a = 6;
				else if( message.SubString(i, 1) == "o" ) a = 7;

				uint n = 0, s = i;

				if( a > 0 )
				{
					n++;
					s++;
				}

				while( s < message.Length() && message.SubString(s, 1) == " " )
				{
					n++;
					s++;
				}

				if( ++g_msgChannel > 6 || g_msgChannel < 3 )
					g_msgChannel = 3;

				const float verpos = g_Pos[i].y + float(g_msgChannel) / 35.0f;

				HUDTextParams textParms;
				textParms.r1 = int(g_Values[a].x);
				textParms.g1 = int(g_Values[a].y);
				textParms.b1 = int(g_Values[a].z);
				textParms.x = g_Pos[i].x;
				textParms.y = verpos;
				textParms.effect = 0;
				textParms.fxTime = 6.0f;
				textParms.holdTime = 6.0f;
				textParms.fadeinTime = 0.5f;
				textParms.fadeoutTime = 0.15f;
				textParms.channel = 1;

				switch( AMXPorts::cvar_iAdminShowActivity.GetInt() )
				{
					case 1:
					{
						g_PlayerFuncs.HudMessageAll( textParms, message.SubString(i + n, message.Length()) ); 
						g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, message.SubString(i + n, message.Length()) );
						break;
					}

					case 2:
					{
						g_PlayerFuncs.HudMessageAll( textParms, string(pUser.pev.netname) + " :   " + message.SubString(i + n, message.Length()) ); 
						g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, string(pUser.pev.netname) + " :   " + message.SubString(i + n, message.Length()) );
						break;
					}

					case 3:
					{
						for( int p = 1; p <= g_PlayerFuncs.GetNumPlayers(); p++ )
						{
							CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(p);

							if( pPlayer is null || !pPlayer.IsConnected() )
								continue;

							if( g_PlayerFuncs.AdminLevel(pPlayer) > ADMIN_NO )
							{
								g_PlayerFuncs.HudMessage( pPlayer, textParms, string(pUser.pev.netname) + " :   " + message.SubString(i + n, message.Length()) ); 
								g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, string(pUser.pev.netname) + " :   " + message.SubString(i + n, message.Length()) );
							}
							else
							{
								g_PlayerFuncs.HudMessage( pPlayer, textParms, message.SubString(i + n, message.Length()) ); 
								g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, message.SubString(i + n, message.Length()) );
							}
						}

						break;
					}
				}

				return HOOK_HANDLED;
			}
		}
		else
		{
			if( message.SubString(0, 1) == "@" )
			{
				pParams.ShouldHide = true;
				message.Trim('@');

				if( g_PlayerFuncs.AdminLevel(pUser) > ADMIN_NO )
					message = "(ADMIN) " + pUser.pev.netname + " : " + message + "\n";
				else
					message = "(PLAYER) " + pUser.pev.netname + " : " + message + "\n";

				for( int j = 1; j < g_PlayerFuncs.GetNumPlayers(); j++ )
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(j);

					if( pPlayer is null )
						continue;

					if( pPlayer !is pUser && g_PlayerFuncs.AdminLevel(pPlayer) > ADMIN_NO )
						g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, message );
				}

				g_PlayerFuncs.ClientPrint( pUser, HUD_PRINTTALK, message );

				return HOOK_HANDLED;
			}
		}

		return HOOK_CONTINUE;
	}

	/*void cmdSay( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		const string name = pAdmin.pev.netname;
		const string message = args.GetString(0);

		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "(ALL) " + name + " :   " + message + "\n" );
		g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTCONSOLE, "(ALL) " + name + " :   " + message + "\n" );
	}*/

	void cmdChat( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		const string name = pAdmin.pev.netname;
		string message = args.GetString(0);
		message = "(ADMINS) " + name + " :   " + message + "\n";

		g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTCONSOLE, message );

		for( int i = 1; i < g_PlayerFuncs.GetNumPlayers(); i++ )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

			if( pPlayer is null || !pPlayer.IsConnected() )
				continue;

			if( AFBase::CheckAccess(pPlayer, ACCESS_H) )
				g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTTALK, message );
		}
	}

	void cmdPsay( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NOALL|TARGETS_NOIMMUNITYCHECK, pTargets) )
		{
			CBasePlayer@ pTarget;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				if( pTarget is pAdmin ) continue;

				g_PlayerFuncs.ClientPrint( pTarget, HUD_PRINTTALK, "(" + pTarget.pev.netname + ") " + pAdmin.pev.netname + " :   " + args.GetString(1) + "\n" );
			}

			g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTCONSOLE, "(" + pTarget.pev.netname + ") " + pAdmin.pev.netname + " :   " + args.GetString(1) + "\n" );
			g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTTALK, "(" + pTarget.pev.netname + ") " + pAdmin.pev.netname + " :   " + args.GetString(1) + "\n" );
		}
	}

	void cmdTsay( AFBaseArguments@ args )
	{
		cmdTCsay( args, true );
	}

	void cmdCsay( AFBaseArguments@ args )
	{
		cmdTCsay( args, false );
	}

	void cmdTCsay( AFBaseArguments@ args, bool bTsay )
	{
		CBasePlayer@ pAdmin = args.User;

		const string color = args.GetString(0);
		string color2;
		const string message = args.GetString(1);
		const string name = pAdmin.pev.netname;

		bool bFound = false;
		uint a = 0;

		for( uint i = 0; i < MAX_CLR; i++ )
		{
			color2 = g_Colors[i];

			if( color == color2 )
			{
				a = i;
				bFound = true;
				break;
			}

			if( bFound == true )
				break;
		}

		uint length = bFound ? color.Length() + 1 : 0;

		if( ++g_msgChannel > 6 || g_msgChannel < 3 )
			g_msgChannel = 3;

		const float verpos = (bTsay ? 0.55f : 0.1f) + float(g_msgChannel) / 35.0f;

		HUDTextParams textParms;
		textParms.r1 = int(g_Values[a].x);
		textParms.g1 = int(g_Values[a].y);
		textParms.b1 = int(g_Values[a].z);
		textParms.x = bTsay ? 0.05f : -1.0f;
		textParms.y = verpos;
		textParms.effect = 0;
		textParms.fxTime = 6.0f;
		textParms.holdTime = 6.0f;
		textParms.fadeinTime = 0.5f;
		textParms.fadeoutTime = 0.15f;
		textParms.channel = -1;

		switch( AMXPorts::cvar_iAdminShowActivity.GetInt() )
		{
			case 1:
			{
				g_PlayerFuncs.HudMessageAll( textParms, message ); 
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, message );
				g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTCONSOLE, message + "\n" );
				break;
			}

			case 2:
			{
				g_PlayerFuncs.HudMessageAll( textParms, name + " :   " + message ); 
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, name + " :   " + message );
				g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTCONSOLE, name + " :   " + message + "\n" );
				break;
			}

			case 3:
			{
				for( int p = 1; p <= g_PlayerFuncs.GetNumPlayers(); p++ )
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(p);

					if( pPlayer is null || !pPlayer.IsConnected() )
						continue;

					if( g_PlayerFuncs.AdminLevel(pPlayer) > ADMIN_NO )
					{
						g_PlayerFuncs.HudMessage( pPlayer, textParms, name + " :   " + message );
						g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, name + " :   " + message );
					}
					else
					{
						g_PlayerFuncs.HudMessage( pPlayer, textParms, message );
						g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, message );
					}
				}

				g_PlayerFuncs.ClientPrint( pAdmin, HUD_PRINTCONSOLE, name + " :   " + message + "\n" );

				break;
			}
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
*/
