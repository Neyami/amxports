/*****************************************************************************************
* AMXX Anti Flood, by AMXX Dev Team
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXAntiFlood amxantiflood;

void AMXAntiFlood_Call()
{
	amxantiflood.RegisterExpansion( amxantiflood );
}

class AMXAntiFlood : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMXX Ports: Anti Flood " + AMXAntiFlood::VERSION;
		this.ShortName = "AMXAF";
	}

	void ExpansionInit()
	{
		RegisterCommand( "amx_flood_time", "!f", "Set in seconds how fast players can chat (chat-flood protection) (default: 0.75)", AFBase::ACCESS_E, @AMXAntiFlood::PluginSettings );

		// .amx_flood_time 0.75
		// as_command .amx-flood-time 0.75

		g_Hooks.RegisterHook( Hooks::Player::ClientSay, @AMXAntiFlood::ClientSay ); 
		@AMXAntiFlood::cvar_flFloodTime = CCVar( "amx-flood-time", 0.75, "Set in seconds how fast players can chat (chat-flood protection) (default: 0.75)", ConCommandFlag::AdminOnly );
	}
}

namespace AMXAntiFlood
{
	const string VERSION = "1.0";
	const string STOP_FLOOD = "Stop flooding the server!";
	CCVar@ cvar_flFloodTime;
	array<float> g_flFlooding(33);
	array<int> g_iFlood(33);

	HookReturnCode ClientSay( SayParameters@ pParams ) 
	{
		CBasePlayer@ pPlayer = pParams.GetPlayer(); 
		float maxChat = cvar_flFloodTime.GetFloat();
		string message = pParams.GetCommand();
		int id = pPlayer.entindex();

		if( message.IsEmpty() )
			return HOOK_CONTINUE;

		if( maxChat > 0 and amxports.containi(message, "buy") == -1 and !AFBase::CheckAccess(pPlayer, ACCESS_B) )
		{
			float nexTime = g_Engine.time;

			if( g_flFlooding[id] > nexTime )
			{
				if( g_iFlood[id] >= 3 )
				{
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, "** " + STOP_FLOOD + " **\n" ); 
					g_flFlooding[id] = nexTime + maxChat + 3.0f;
					pParams.ShouldHide = true;
					return HOOK_HANDLED;
				}
				g_iFlood[id]++;
			}
			else if( g_iFlood[id] > 0 )
				g_iFlood[id]--;

			g_flFlooding[id] = nexTime + maxChat;
		}

		return HOOK_CONTINUE;
	}

	void PluginSettings( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( pPlayer is null )
		{
			amxantiflood.Log( "PluginSettings: pPlayer is null!\n" );
			return;
		}

		const string sCommand = args.RawArgs[0];

		if( args.GetCount() < 1 )//If no args are supplied
		{
			if( sCommand == "amx_flood_time" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_flood_time\" is \"" + cvar_flFloodTime.GetFloat() + "\"\n" );
		}
		else if( args.GetCount() == 1 and args.GetFloat(0) != cvar_flFloodTime.GetFloat() )//If one arg is supplied (value to set)
		{
			cvar_flFloodTime.SetFloat(args.GetFloat(0));
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_flood_time\" changed to \"" + cvar_flFloodTime.GetFloat() + "\"\n" );
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
