/*****************************************************************************************
* AMXX Slots Reservation, by AMXX Dev Team
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXSlotRes amxslotres;

void AMXSlotRes_Call()
{
	amxslotres.RegisterExpansion( amxslotres );
}

class AMXSlotRes : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMXX Ports: Slots Reservation " + AMXSlotRes::VERSION;
		this.ShortName = "AMXSR";
	}

	void ExpansionInit()
	{
		RegisterCommand( "amx_hideslots", "!i", "If you set this to 1, you can hide slots on your server. (default: 0)", AFBase::ACCESS_E, @AMXSlotRes::PluginSettings );
		RegisterCommand( "amx_reservation", "!i", "Amount of slots to reserve. (default: 0)", AFBase::ACCESS_E, @AMXSlotRes::PluginSettings );

		// .amx_hideslots 0
		// as_command .amx-hideslots 0

		// .amx_reservation 0
		// as_command .amx-reservation 0

		@AMXSlotRes::cvar_iHideSlots = CCVar( "amx-hideslots", 0, "If you set this to 1, you can hide slots on your server. (default: 0)", ConCommandFlag::AdminOnly );
		@AMXSlotRes::cvar_iReservedSlots = CCVar( "amx-reservation", 0, "Amount of slots to reserve. (default: 0)", ConCommandFlag::AdminOnly );
	}

	void MapInit()
	{
		if( AMXSlotRes::cvar_iHideSlots.GetInt() == 1 )
		{
			int maxplayers = g_Engine.maxClients;
			int players = g_PlayerFuncs.GetNumPlayers();
			int limit = maxplayers - AMXSlotRes::cvar_iReservedSlots.GetInt();
			AMXSlotRes::setVisibleSlots( players, maxplayers, limit );
		}
	}

	void ClientConnectEvent( CBasePlayer@ pPlayer )
	{
		int maxplayers = g_Engine.maxClients;
		int players = g_PlayerFuncs.GetNumPlayers();
		int limit = maxplayers - AMXSlotRes::cvar_iReservedSlots.GetInt();

		if( AFBase::CheckAccess(pPlayer, ACCESS_B) or (players <= limit) )
		{
			if( AMXSlotRes::cvar_iHideSlots.GetInt() == 1 )
				AMXSlotRes::setVisibleSlots( players, maxplayers, limit );
		}
		else
			g_EngineFuncs.ServerCommand("kick #" + string(g_EngineFuncs.GetPlayerUserId(pPlayer.edict())) + " \"" + AMXSlotRes::DROPPED_RES + "\"\n" );
	}

	void ClientDisconnectEvent( CBasePlayer@ pPlayer )
	{
		if( AMXSlotRes::cvar_iHideSlots.GetInt() == 1 )
		{
			int maxplayers = g_Engine.maxClients;
			AMXSlotRes::setVisibleSlots( (g_PlayerFuncs.GetNumPlayers() - 1), maxplayers, maxplayers - AMXSlotRes::cvar_iReservedSlots.GetInt() );
		}
	}
}

namespace AMXSlotRes
{
	const string VERSION = "1.0";
	const string DROPPED_RES = "Dropped due to slot reservation";
	CCVar@ cvar_iHideSlots;
	CCVar@ cvar_iReservedSlots;

	void setVisibleSlots( int players, int maxplayers, int limit )
	{
		int num = players + 1;

		if( players == maxplayers )
			num = maxplayers;
		else if( players < limit )
			num = limit;

		g_EngineFuncs.CVarSetFloat( "sv_visiblemaxplayers", num );
	}

	void PluginSettings( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( pPlayer is null )
		{
			amxslotres.Log( "PluginSettings: pPlayer is null!\n" );
			return;
		}

		const string sCommand = args.RawArgs[0];

		if( args.GetCount() < 1 )//If no args are supplied
		{
			if( sCommand == "amx_hideslots" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_hideslots\" is \"" + cvar_iHideSlots.GetInt() + "\"\n" );
			else if( sCommand == "amx_reservation" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_reservation\" is \"" + cvar_iReservedSlots.GetInt() + "\"\n" );
		}
		else if( args.GetCount() == 1 )//If one arg is supplied (value to set)
		{
			if( sCommand == "amx_hideslots" and args.GetInt(0) != cvar_iHideSlots.GetInt() )
			{
				cvar_iHideSlots.SetInt(args.GetInt(0));
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_hideslots\" changed to \"" + cvar_iHideSlots.GetInt() + "\"\n" );
			}
			else if( sCommand == "amx_reservation" and args.GetInt(0) != cvar_iReservedSlots.GetInt() )
			{
				cvar_iReservedSlots.SetInt(args.GetInt(0));
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"amx_reservation\" changed to \"" + cvar_iReservedSlots.GetInt() + "\"\n" );
			}
		}
	}
}

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		January 15 2018
*	-------------------------
*	- First release
*	-------------------------
*/
