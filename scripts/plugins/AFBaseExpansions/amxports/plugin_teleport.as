/*****************************************************************************************
* Teleportation commands, by bahrmanou © 2002-2006 e-mail: Amiga5707@hotmail.com
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
AMXTeleport amxteleport;

void AMXTeleport_Call()
{
	amxteleport.RegisterExpansion( amxteleport );
}

class AMXTeleport : AFBaseClass
{

	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMX Teleportation Commands " + AMXTeleport::VERSION;
		this.ShortName = "AMXTC";
	}

	void ExpansionInit()
	{
		string efstr;
		snprintf( efstr, "<n> - get/set teleporting effect ([-1,%1], 0 = random, -1 = off). (default: 1)", AMXTeleport::NUM_EFFECTS-1 );

		RegisterCommand( "amxtc_tpallow", "s", "(on|off|0|1) - enable/disable teleporting.", AFBase::ACCESS_H, @AMXTeleport::TPAllow );
		RegisterCommand( "amxtc_tpallowuser", "ss", "(target) ('on'|'1'|'off'|'0') - enable/disable teleporting for target.", AFBase::ACCESS_H, @AMXTeleport::TPAllowUser );
		RegisterCommand( "amxtc_tpeffect", "!i", efstr, AFBase::ACCESS_H, @AMXTeleport::TPEffect );
		RegisterCommand( "amxtc_tpdelay", "!f", "<delay> - set a delay between 2 posme (0 = OFF).", AFBase::ACCESS_H, @AMXTeleport::TPDelay );
		RegisterCommand( "amxtc_tpempty", "", "- remove all positions in list.", AFBase::ACCESS_H, @AMXTeleport::TPEmpty );
		RegisterCommand( "amxtc_tpadd", "s", "(target) - add targets position in first free slot.", AFBase::ACCESS_H, @AMXTeleport::TPAdd );
		RegisterCommand( "amxtc_tpmem", "si", "(target) (Slot_num) - memorize target position in a slot.", AFBase::ACCESS_H, @AMXTeleport::TPMem );
		RegisterCommand( "amxtc_tplist", "", "- display memorised positions.", AFBase::ACCESS_H, @AMXTeleport::TPList );
		RegisterCommand( "amxtc_tpload", "", "- load positions from file.", AFBase::ACCESS_H, @AMXTeleport::TPLoad );
		RegisterCommand( "amxtc_tpsave", "", "- save positions to file.", AFBase::ACCESS_H, @AMXTeleport::TPSave );
		RegisterCommand( "amxtc_tpname", "i!s", "(Slot_num) <Slot_name> - name or unname a slot.", AFBase::ACCESS_H, @AMXTeleport::TPName );
		RegisterCommand( "amxtc_tpcopy", "ss", "(user) (target) - copy the user position to target.", AFBase::ACCESS_H, @AMXTeleport::TPCopy );
		RegisterCommand( "amxtc_tpstack", "s", "(target) - stack player(s) on you.", AFBase::ACCESS_H, @AMXTeleport::TPStack );
		RegisterCommand( "amxtc_tp", "!ss", "<target> <Slot_num | Slot_name> - teleport target to a g_vecSlot.", AFBase::ACCESS_H, @AMXTeleport::TPSlot );
		RegisterCommand( "amxtc_tpgo", "sfff!fff", "(target) (x) (y) (z) <x> <y> <z> - teleport target to coordinates (angles optional).", AFBase::ACCESS_H, @AMXTeleport::TPGo );
		RegisterCommand( "amxtc_tpsend", "ss", "(user) (target) - stack user on target.", AFBase::ACCESS_H, @AMXTeleport::TPSend );
		RegisterCommand( "amxtc_tpaim", "s", "(target) - send player(s) to where you're looking.", AFBase::ACCESS_H, @AMXTeleport::TPAim );
		RegisterCommand( "amxtc_tpinfo", "", " - display the current position coordinates.", AFBase::ACCESS_H, @AMXTeleport::TPInfo );

		RegisterCommand( "say saveme", "", "- saves your position into slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdSaveme, false, true );
		RegisterCommand( "say /s", "", "- saves your position into slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdSaveme, false, true );
		RegisterCommand( "say saveme2", "", "- saves your position into slot 2", AFBase::ACCESS_Z, @AMXTeleport::cmdSaveme2, false, true );
		RegisterCommand( "say posme", "", "- loads your position from slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdPosme, false, true );
		RegisterCommand( "say /t", "", "- loads your position from slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdPosme, false, true );
		RegisterCommand( "say posme2", "", "- loads your position from slot 2", AFBase::ACCESS_Z, @AMXTeleport::cmdPosme2, false, true );
		RegisterCommand( "say /stats", "", "- displays checkpoint stats.", AFBase::ACCESS_Z, @AMXTeleport::cmdStats, false, true );
		RegisterCommand( "say /teleport_version", "", "", AFBase::ACCESS_Z, @AMXTeleport::cmdVersion, false, true );

		@AMXTeleport::cvar_Enabled = CCVar( "amxtc_enabled", 1, "Enable/disable teleport plugin. (default: 1)", ConCommandFlag::AdminOnly );
		@AMXTeleport::cvar_TeleportEffect = CCVar( "amxtc_teleporteffect", 1, efstr, ConCommandFlag::AdminOnly );
		@AMXTeleport::cvar_AutoUnstuck = CCVar( "amxtc_autounstuck", 1, "Enable/disable auto-unstuck. (default: 1)", ConCommandFlag::AdminOnly );

		g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @AMXTeleport::ClientPutInServer );

		// empty and load list (if file exists) at map change automatically
		for( int i = 0; i < AMXTeleport::NUMSLOTS; i++ )
		{
			AMXTeleport::g_vecSlotName[i] = "pos" + (i+1);
			AMXTeleport::g_vecSlot[i] = Vector(-1, -1, -1);
		}

		string map, cfgdir;

		amxports.get_mapname( map );
		cfgdir = "scripts/plugins/store/amxports/configs";

		AMXTeleport::g_cfgfilepath = string(cfgdir) + "/pos";

		/*if( !dir_exists(AMXTeleport::g_cfgfilepath) )
			mkdir(AMXTeleport::g_cfgfilepath)*/

		AMXTeleport::g_cfgfilepath = string(cfgdir) + "/pos/" + map + ".pos";
		AMXTeleport::read_file_( AMXTeleport::g_cfgfilepath );

		if( AMXTeleport::g_pCheckStuck !is null )
			g_Scheduler.RemoveTimer( AMXTeleport::g_pCheckStuck );

		@AMXTeleport::g_pCheckStuck = g_Scheduler.SetTimeout( "checkstuck", 0.1f );
	}

	void MapInit()
	{
		//if( g_EngineFuncs.NumberOfEntities() < g_Engine.maxEntities - 15*g_Engine.maxClients - 2 )
		for( uint i = 0; i < AMXTeleport::g_tp_sounds.length(); i++ )
			g_SoundSystem.PrecacheSound( AMXTeleport::g_tp_sounds[i] );
	}

	void ClientConnectEvent( CBasePlayer@ pPlayer )
	{
		int id = pPlayer.entindex();

		AMXTeleport::g_bPlayerAllowed[id] = true;
		AMXTeleport::g_vecUserSlot[id] = Vector(-1, -1, -1);
		AMXTeleport::g_vecUserSlot2[id] = Vector(-1, -1, -1);
		AMXTeleport::g_vecUserSlotAngle[id] = Vector(-1, -1, -1);
		AMXTeleport::g_vecUserSlotAngle2[id] = Vector(-1, -1, -1);
		AMXTeleport::g_flLastTime[id] = 0;
		AMXTeleport::g_Stats[id].x = AMXTeleport::g_Stats[id].y = 0;
	}

	void StopEvent()
	{
		if( AMXTeleport::g_pCheckStuck !is null )
			g_Scheduler.RemoveTimer( AMXTeleport::g_pCheckStuck );
	}

	void StartEvent()
	{
		if( AMXTeleport::g_pCheckStuck !is null )
			g_Scheduler.RemoveTimer( AMXTeleport::g_pCheckStuck );

		@AMXTeleport::g_pCheckStuck = g_Scheduler.SetTimeout( "checkstuck", 0.1f );
	}
}

namespace AMXTeleport
{
	const string PLUGNAME = "plugin_teleport";
	const string VERSION = "1.0";

	const uint NUMSLOTS = 40;
	const int NUM_EFFECTS = g_effects.length();

	array<Vector2D> g_Stats(33);
	array<string> g_vecSlotName(NUMSLOTS);
	array<Vector> g_vecSlot(NUMSLOTS);
	array<Vector> g_vecSlotAngle(NUMSLOTS);
	array<bool> g_bPlayerAllowed(33);
	array<Vector> g_vecUserSlot(33);
	array<Vector> g_vecUserSlot2(33);
	array<Vector> g_vecUserSlotAngle(33);
	array<Vector> g_vecUserSlotAngle2(33);
	array<float> g_flLastTime(33);

	bool bPosDelayStatus = true; // teleport delay is ON by default
	float g_flPosDelay = 2.0f; // delay = 2 secs

	CCVar@ cvar_Enabled, cvar_TeleportEffect, cvar_AutoUnstuck;

	const array<string> g_effects =
	{
		"Random",
		"Teleport",
		"Sparks",
		"Lavasplash",
		"Explosion",
		"Implosion",
		"Light"
	};

	const array<string> g_tp_sounds =
	{
		"items/r_item1.wav",
		"items/r_item2.wav",
		"items/health1.wav"
	};

	CScheduledFunction@ g_pCheckStuck = null;

	string g_cfgfilepath;

	HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
	{
		int id = pPlayer.entindex();
		g_bPlayerAllowed[id] = true;
		g_flLastTime[id] = 0;
		g_Stats[id].x = g_Stats[id].y = 0;

		return HOOK_CONTINUE;
	}

	/*****************************************************************************************
	*
	*	amxtc_tpallow
	*
	*		syntax:
	*		.amxtc_tpallow flag						flag: 'on' | 'off' | 0 | 1
	*		.amxtc_tpallow							display current teleporting status
	*
	******************************************************************************************/
	void TPAllow( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		bool flag = cvar_Enabled.GetBool();

		if( args.GetCount() > 0 )
		{ // argument present
			string argument = args.GetString(0);

			if( amxports.equali(argument, "on") == 1 or atoi(argument) == 1 )
			{
				if( flag )
					amxteleport.Tell( "Teleportation already ON!", pAdmin, HUD_PRINTCONSOLE );
				else
				{
					amxteleport.Tell( "Teleportation is now ON.", pAdmin, HUD_PRINTCONSOLE );
					cvar_Enabled.SetInt(1);
				}
			}
			else
			{
				if( !flag )
					amxteleport.Tell( "Teleportation already OFF!", pAdmin, HUD_PRINTCONSOLE );
				else
				{
					amxteleport.Tell( "Teleportation is now OFF.", pAdmin, HUD_PRINTCONSOLE );
					cvar_Enabled.SetInt(0);
				}
			}
		}
		else
		{ // no argument, read the current
			if( flag )
				amxteleport.Tell( "Teleportation is ON.", pAdmin, HUD_PRINTCONSOLE );
			else
				amxteleport.Tell( "Teleportation is OFF.", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpallowuser
	*
	*		syntax:
	*		.amxtc_tpallowuser (user) (flag)		flag: 'on' | 'off' | '0' | '1'
	*
	******************************************************************************************/
	void TPAllowUser( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), 0, pTargets) )
		{
			CBasePlayer@ pTarget;
			int id;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];
				if( pTarget is null ) continue;

				id = pTarget.entindex();

				if( args.GetString(1) == "on" or args.GetString(1) == "1" )
				{
					g_bPlayerAllowed[id] = true;
					amxteleport.Tell( "Player " + pTarget.pev.netname + " can now teleport.", pAdmin, HUD_PRINTCONSOLE );
				}
				else
				{
					g_bPlayerAllowed[id] = false;
					amxteleport.Tell( "Player " + pTarget.pev.netname + " is now unable to teleport.", pAdmin, HUD_PRINTCONSOLE );
				}
			}
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpeffect
	*
	*		syntax:
	*		.amxtc_tpeffect (n)						get/set teleporting effect
	*
	******************************************************************************************/
	void TPEffect( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( args.GetCount() < 1 )
		{
			amxteleport.Tell( "Effects:", pPlayer, HUD_PRINTCONSOLE );
			for( int i = 0; i < NUM_EFFECTS; i++ )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, string(i) + " : " + g_effects[i] + "\n" );

			amxteleport.Tell( "Teleport effect is currently: " + cvar_TeleportEffect.GetInt() + ".\n", pPlayer, HUD_PRINTCONSOLE );
			return;
		}

		int iEffect = args.GetInt(0);

		if( iEffect < -1 or iEffect > NUM_EFFECTS-1 )
		{
			amxteleport.Tell( "Effect must be in range [-1," + string(NUM_EFFECTS-1) + "]!", pPlayer, HUD_PRINTCONSOLE );
			return;
		}

		cvar_TeleportEffect.SetInt(iEffect);
	}

	/*****************************************************************************************
	*
	*	amxtc_tpdelay
	*
	*		syntax:
	*		.amxtc_tpdelay							get the delay status and value
	*		.amxtc_tpdelay 0						set delay status OFF
	*		.amxtc_tpdelay (secs#)					set delay status ON and value in seconds
	*
	******************************************************************************************/
	void TPDelay( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;

		if( args.GetCount() < 1 )
		{
			if( !bPosDelayStatus )
				amxteleport.Tell( "Teleportation delay is disabled.", pPlayer, HUD_PRINTCONSOLE );
			else
				amxteleport.Tell( "Teleportation delay is enabled and is set to " + g_flPosDelay + " seconds.", pPlayer, HUD_PRINTCONSOLE );

			return;
		}

		float delay = args.GetFloat(0);

		if( delay == 0 )
		{
			bPosDelayStatus = false;
			amxteleport.Tell( "Teleportation delay is now disabled.", pPlayer, HUD_PRINTCONSOLE );
		}
		else
		{
			bPosDelayStatus = true;
			g_flPosDelay = delay;
			amxteleport.Tell( "Teleportation delay is now enabled and is set to " + delay + " seconds.", pPlayer, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpempty
	*
	*		syntax:
	*		.amxtc_tpempty							empty positions list
	*
	******************************************************************************************/
	void TPEmpty( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;

		for( int i = 0; i < NUMSLOTS; i++ )
		{
			g_vecSlotName[i] = "pos" + (i+1);
			g_vecSlot[i] = Vector(-1, -1, -1);
		}

		amxteleport.Tell( "The list is now empty.", pAdmin, HUD_PRINTCONSOLE );
	}

	/*****************************************************************************************
	*
	*	amxtc_tpadd
	*
	*		syntax:
	*		.amxtc_tpadd (target)					add target position to list
	*		.amxtc_tpadd							add command-user position to list
	*
	******************************************************************************************/
	void TPAdd( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NOALL|TARGETS_NOIMMUNITYCHECK, pTargets) )
		{
			CBasePlayer@ pTarget;
			bool bFailed = false;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				Vector origin, angles;

				origin = pTarget.GetOrigin();
				angles = pTarget.pev.angles;

				for( int j = 0; j < NUMSLOTS; j++ )
				{
					if( g_vecSlot[j].x == -1 and g_vecSlot[j].y == -1 and g_vecSlot[j].z == -1 )
					{
						g_vecSlot[j] = origin;
						g_vecSlotAngle[j] = angles;

						amxteleport.Tell( "Success : player " + pTarget.pev.netname + "'s position added in slot #" + (j+1) + ".", pAdmin, HUD_PRINTCONSOLE );
						return;
					}
					else bFailed = true;
				}
			}

			if( bFailed )
				amxteleport.Tell( "Failed to add position, slots are full!", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpmem
	*
	*		syntax:
	*		.amxtc_tpmem (user) (slot#)				memorize user's position in slot#
	*
	******************************************************************************************/
	void TPMem( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NOALL|TARGETS_NOIMMUNITYCHECK, pTargets) )
		{
			CBasePlayer@ pTarget;
			int slot = args.GetInt(1);

			if( slot < 1 or slot >= NUMSLOTS )
			{
				amxteleport.Tell( "Bad slot number: " + slot + "!", pAdmin, HUD_PRINTCONSOLE );
				return;
			}

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				Vector origin, angles;

				origin = pTarget.GetOrigin();
				angles = pTarget.pev.angles;

				g_vecSlot[slot-1] = origin;
				g_vecSlotAngle[slot-1] = angles;
			}

			amxteleport.Tell( "Success: player " + pTarget.pev.netname + "'s position set in slot #" + slot + ".", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tplist
	*
	*		syntax:
	*		.amxtc_tplist							display the list
	*
	******************************************************************************************/
	void TPList( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		int n = 0;

		for( int i = 0; i < NUMSLOTS; i++ )
		{
			if( !(g_vecSlot[i].x == -1 and g_vecSlot[i].y == -1 and g_vecSlot[i].z == -1) )
			{
				n++;
				amxteleport.Tell( "g_vecSlot " + (i+1) + ": X " + g_vecSlot[i].x + ", Y " + g_vecSlot[i].y + ", Z " + g_vecSlot[i].z + " ; " + g_vecSlotName[i], pAdmin, HUD_PRINTCONSOLE );
			}
		}

		if( n == 0 )
			amxteleport.Tell( "The list is empty.", pAdmin, HUD_PRINTCONSOLE );
	}

	/*****************************************************************************************
	*
	*	amxtc_tpload
	*
	*		syntax:
	*		.amxtc_tpload								load the list from defaultfile
	*
	******************************************************************************************/
	void TPLoad( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;

		if( read_file_(g_cfgfilepath) )
			amxteleport.Tell( "Success: loading from file " + g_cfgfilepath + ".", pAdmin, HUD_PRINTCONSOLE );
		else
			amxteleport.Tell( "Unknown file " + g_cfgfilepath + "!", pAdmin, HUD_PRINTCONSOLE );
	}

	/*****************************************************************************************
	*
	*	amxtc_tpsave
	*
	*		syntax:
	*		.amxtc_tpsave								save the list in defaultfile
	*
	******************************************************************************************/
	void TPSave( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;

		File@ file = g_FileSystem.OpenFile( g_cfgfilepath, OpenFile::WRITE );
		if( file !is null and file.IsOpen() )
		{
			for( int i = 0; i < NUMSLOTS; i++ )
			{
				string txt;
				snprintf( txt, "%1 %2 %3 %4 %5 %6 %7", g_vecSlot[i].x, g_vecSlot[i].y, g_vecSlot[i].z, g_vecSlotAngle[i].x, g_vecSlotAngle[i].y, g_vecSlotAngle[i].z, g_vecSlotName[i] );

				if( i < NUMSLOTS-1 )
					file.Write( txt + "\n" );
				else
					file.Write( txt );

				g_Game.AlertMessage( at_console, "Wrote to log: \"%1\"\n", txt );
			}

			file.Close();
		}
		else
		{
			amxteleport.Tell( "Error writing file " + g_cfgfilepath + "!", pAdmin, HUD_PRINTCONSOLE );
			return;
		}

		amxteleport.Tell( "Success: saved to file \"" + g_cfgfilepath + "\"", pAdmin, HUD_PRINTCONSOLE );
	}

	/*****************************************************************************************
	*
	*	amxtc_tpname
	*
	*		syntax:
	*		.amxtc_tpname (slot#) (name)				name the slot number slot#
	*		.amxtc_tpname (slot#)						unname the slot slot# (back to name 'posxx' where xx is the slot number)
	*
	******************************************************************************************/
	void TPName( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		int slot = args.GetInt(0);
		string name = args.GetCount() > 1 ? args.GetString(1) : "";

		if( slot < 1 or slot >= NUMSLOTS )
		{
			amxteleport.Tell( "Bad slot number: " + slot + "!", pAdmin, HUD_PRINTCONSOLE );
			return;
		}

		if( name == "" ) // no name given, unname it
		{
			g_vecSlotName[slot-1] = "pos" + slot;
			amxteleport.Tell( "Cleared the name of slot #" + slot, pAdmin, HUD_PRINTCONSOLE );
		}
		else
		{
			g_vecSlotName[slot-1] = name;
			amxteleport.Tell( "Success: slot #" + slot + " renamed to \"" + name + "\"", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpcopy
	*
	*		syntax:
	*		.amxtc_tpcopy (user1) (user2)				copy personal position of user1 (saved by 'saveme') to user2
	*
	******************************************************************************************/
	void TPCopy( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NOALL, pTargets) )
		{
			CBasePlayer@ pTarget1 = pTargets[0];	//copy from
			CBasePlayer@ pTarget2;					//copy to
			array<CBasePlayer@> pTargets2;

			if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(1), TARGETS_NOALL, pTargets2) )
				@pTarget2 = pTargets2[0];
			else
				return;

			int user1 = pTarget1.entindex(), user2 = pTarget2.entindex();

			if( g_vecUserSlot[user1].x == -1 and g_vecUserSlot[user1].y == -1 and g_vecUserSlot[user1].z == -1 )
				amxteleport.Tell( "Failed : position of user " + pTarget1.pev.netname + " is not set yet!", pAdmin, HUD_PRINTCONSOLE );
			else
			{
				g_vecUserSlot[user2] = g_vecUserSlot[user1];
				g_vecUserSlotAngle[user2] = g_vecUserSlotAngle[user1];

				amxteleport.Tell( "Succeeded : copied user " + pTarget1.pev.netname + "'s position to user " + pTarget2.pev.netname + ".", pAdmin, HUD_PRINTCONSOLE );
			}
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpstack
	*
	*		syntax:
	*		.amxtc_tpstack							stack all players on your head
	*		.amxtc_tpstack (user(s))				stack only (user(s)) on your head
	*
	******************************************************************************************/
	void TPStack( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NOME|TARGETS_NODEAD|TARGETS_NOIMMUNITYCHECK, pTargets) )
		{
			CBasePlayer@ pTarget;
			Vector origin = pAdmin.pev.origin;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				if( pTarget !is pAdmin )// Don't teleport command user
				{
					pTarget.pev.velocity = g_vecZero;
					origin[2] += 76;
					pTarget.SetOrigin( origin );
				}
			}

			amxteleport.Tell( "Successfully stacked target(s)", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tp
	*
	*		syntax:
	*		.amxtc_tp (user) (slot#)					teleport user to slot#
	*		.amxtc_tp (user) (slotname)					teleport user to slotname
	*		.amxtc_tp (user)							teleport user to last slot
	*		.amxtc_tp									teleport commanduser to last slot
	*
	******************************************************************************************/
	void TPSlot( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;
		int iArgCount = args.GetCount();
		string sTarget = iArgCount >= 1 ? args.GetString(0) : "@me";

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, sTarget, 0, pTargets) )
		{
			CBasePlayer@ pTarget;
			int slotnum = 0;
			bool bSuccess = false;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];
				int user = pTarget.entindex();

				if( iArgCount <= 1 )
				{
					bool found = false;

					for( int j = NUMSLOTS-1; j >= 0; j-- )
					{
						if( g_vecSlot[j].x != -1 or g_vecSlot[j].y != -1 or g_vecSlot[j].z != -1 )
						{
							found = true;
							slotnum = j;
							break;
						}
					}

					if( !found )
					{
						amxteleport.Tell( "No slot left!", pAdmin, HUD_PRINTCONSOLE );
						return;
					}
				}
				else
				{
					string arg2 = args.GetString(1);
					slotnum = atoi(arg2);

					if( slotnum == 0 ) //?? !slotnum
					{ // maybe a slot name
						for( int k = 0; k < NUMSLOTS; k++ )
						{
							if( amxports.containi(g_vecSlotName[k], arg2) != -1 )
							{
								slotnum = (k+1);
								break;
							}
						}
					}

					if( slotnum == 0 or slotnum > NUMSLOTS ) //?? !slotnum
					{
						amxteleport.Tell( "Bad slot number or unknown slot: " + arg2 + "!", pAdmin, HUD_PRINTCONSOLE );
						return;
					}

					if( g_vecSlot[slotnum-1].x == -1 and g_vecSlot[slotnum-1].y == -1 and g_vecSlot[slotnum-1].z == -1 )
					{
						amxteleport.Tell( "Unitialized slot: " + slotnum + "!", pAdmin, HUD_PRINTCONSOLE );
						return;
					}
				}

				string userName;
				amxports.get_user_name( user, userName );

				if( !AFBase::CheckAccess(pAdmin, ACCESS_T) and AFBase::CheckAccess(pTarget, ACCESS_A) )
				{
					amxteleport.Tell( string(userName) + " is immune, you cannot do that!", pAdmin, HUD_PRINTCONSOLE );
					return;
				}

				Vector angles = g_vecZero;
				angles = g_vecSlotAngle[slotnum-1];

				pTarget.pev.velocity = g_vecZero;
				g_EntityFuncs.SetOrigin( pTarget, g_vecSlot[slotnum-1] );
				pTarget.pev.angles = angles;
				pTarget.pev.fixangle = FAM_FORCEVIEWANGLES;

				bSuccess = true;
				//msg_show_activity( pAdmin.pev.netname, userName );
			}

			amxteleport.Tell( "Success: player(s) sent to slot " + slotnum + ".", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpgo
	*
	*		syntax:
	*		.amxtc_tpgo #user x y z x y z			teleport user to coordinates (optional angles)
	*
	******************************************************************************************/
	void TPGo( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;
		bool bSuccess = false;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), 0, pTargets) )
		{
			CBasePlayer@ pTarget;
			float x = args.GetFloat(1);
			float y = args.GetFloat(2);
			float z = args.GetFloat(3);

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				if( !AFBase::CheckAccess(pAdmin, ACCESS_T) and AFBase::CheckAccess(pTarget, ACCESS_A) )
				{
					amxteleport.Tell( string(pTarget.pev.netname) + " is immune, you cannot do that!", pAdmin, HUD_PRINTCONSOLE );
					continue;
				}

				pTarget.pev.velocity = g_vecZero;
				pTarget.pev.flFallVelocity = 0.0f;
				pTarget.SetOrigin( Vector(x, y, z) );

				if( args.GetCount() > 4 )
				{
					pTarget.pev.angles = Vector(args.GetFloat(4), args.GetFloat(5), args.GetFloat(6));
					pTarget.pev.fixangle = FAM_FORCEVIEWANGLES;
				}

				bSuccess = true;
			}

			if( bSuccess )
				amxteleport.Tell( "Success: player(s) were sent to (" + x + " " + y + " " + z + ").", pAdmin, HUD_PRINTCONSOLE );

			//msg_show_activity( pAdmin.pev.netname, userName );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpsend
	*
	*		syntax:
	*		.amxtc_tpsend (user1) (user2)			send #user1 to #user2 current position (stack on #user2)
	*
	******************************************************************************************/
	void TPSend( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), 0, pTargets) )
		{
			CBasePlayer@ pTarget;
			array<CBasePlayer@> pTargets2;

			if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(1), TARGETS_NOIMMUNITYCHECK|TARGETS_NOALL, pTargets2) )
			{
				CBasePlayer@ pTarget2 = pTargets2[0];

				for( uint i = 0; i < pTargets.length; i++ )
				{
					@pTarget = pTargets[i];
					Vector origin = pTarget2.pev.origin;

					origin.z += 96;

					pTarget.pev.velocity = g_vecZero;
					pTarget.SetOrigin( origin );
					pTarget.pev.angles = pTarget2.pev.angles;
					pTarget.pev.fixangle = FAM_FORCEVIEWANGLES;
				}

				amxteleport.Tell( "Success : Player(s) were sent to " + pTarget2.pev.netname + ".", pAdmin, HUD_PRINTCONSOLE );
				//msg_show_activity( pAdmin.pev.netname, strUser1 );
			}
		}
	}

	void TPAim( AFBaseArguments@ args )
	{	
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NODEAD|TARGETS_NOIMMUNITYCHECK, pTargets) )
		{
			CBasePlayer@ pTarget;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				TraceResult tr;
				Vector vecStart = pAdmin.GetGunPosition();
				Vector angles;
				
				Math.MakeVectors( pAdmin.pev.v_angle );
				g_Utility.TraceLine( vecStart, vecStart + g_Engine.v_forward * 4096, dont_ignore_monsters, pAdmin.edict(), tr );
				//g_Utility.TraceHull( vecStart, vecStart + g_Engine.v_forward * 4096, dont_ignore_monsters, human_hull, pAdmin.edict(), tr );

				angles = pTarget.pev.angles;
				angles.y += 180.0f;
				if( tr.pHit !is null )
				{
					pTarget.pev.velocity = g_vecZero;
					pTarget.SetOrigin(tr.vecEndPos+Vector(0, 0, 38));
					pTarget.pev.angles = angles;
					pTarget.pev.fixangle = FAM_FORCEVIEWANGLES;
				}
			}

			amxteleport.Tell( "Successfully teleported target(s)", pAdmin, HUD_PRINTCONSOLE );
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpinfo
	*
	*	syntax:
	*	amxtc_tpinfo	display coords to user.
	*
	******************************************************************************************/
	void TPInfo( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		Vector origin = pPlayer.pev.origin;
		Vector angles = pPlayer.pev.v_angle;
		string msg;

		snprintf( msg, "Your position is: X = %1, Y = %2, Z = %3.", origin.x, origin.y, origin.z );
		amxteleport.Tell( msg, pPlayer, HUD_PRINTCONSOLE );
		snprintf( msg, "Your angles are: X = %1, Y = %2, Z = %3.", angles.x, angles.y, angles.z );
		amxteleport.Tell( msg, pPlayer, HUD_PRINTCONSOLE );
	}

	void cmdPosme( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		int id = pPlayer.entindex();

		if( !PlayerAllowedToPos(pPlayer) ) return;

		if( g_vecUserSlot[id].x != -1 or g_vecUserSlot[id].y != -1 or g_vecUserSlot[id].z != -1 )
		{
			pPlayer.pev.velocity = g_vecZero;
			pPlayer.pev.flFallVelocity = 0.0f;
			pPlayer.SetOrigin( g_vecUserSlot[id] );
			pPlayer.pev.angles = g_vecUserSlotAngle[id];
			pPlayer.pev.fixangle = FAM_FORCEVIEWANGLES;
			do_effect( g_vecUserSlot[id] );
			do_sound( pPlayer, 0 );
			amxteleport.Tell( "Teleporting succeeded.", pPlayer, HUD_PRINTTALK );
			g_Stats[id].y++;
		}
		else
			amxteleport.Tell( "Your position was not saved before.", pPlayer, HUD_PRINTTALK );
	}

	void cmdPosme2( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		int id = pPlayer.entindex();

		if( !PlayerAllowedToPos(pPlayer) ) return;

		if( g_vecUserSlot2[id].x != -1 or g_vecUserSlot2[id].y != -1 or g_vecUserSlot2[id].z != -1 )
		{
			pPlayer.pev.velocity = g_vecZero;
			pPlayer.pev.flFallVelocity = 0.0f;
			pPlayer.SetOrigin( g_vecUserSlot2[id] );
			pPlayer.pev.angles = g_vecUserSlotAngle2[id];
			pPlayer.pev.fixangle = FAM_FORCEVIEWANGLES;
			do_effect( g_vecUserSlot2[id] );
			do_sound( pPlayer, 0 );
			amxteleport.Tell( "Teleporting succeeded.", pPlayer, HUD_PRINTTALK );
			g_Stats[id].y++;
		}
		else
			amxteleport.Tell( "Your position was not saved before.", pPlayer, HUD_PRINTTALK );
	}

	void cmdSaveme( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		int id = pPlayer.entindex();

		if( !PlayerAllowedToSave(pPlayer) ) return;

		g_vecUserSlot[id] = pPlayer.pev.origin;
		g_vecUserSlotAngle[id] = pPlayer.pev.v_angle;
		do_sound( pPlayer, 1 );
		amxteleport.Tell( "Your position has been saved.", pPlayer, HUD_PRINTTALK );
		g_Stats[id].x++;
	}

	void cmdSaveme2( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		int id = pPlayer.entindex();

		if( !PlayerAllowedToSave(pPlayer) ) return;

		g_vecUserSlot2[id] = pPlayer.pev.origin;
		g_vecUserSlotAngle2[id] = pPlayer.pev.v_angle;
		do_sound( pPlayer, 1 );
		amxteleport.Tell( "Your position has been saved.", pPlayer, HUD_PRINTTALK );
		g_Stats[id].x++;
	}

	void cmdStats( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		int id = pPlayer.entindex();

		if( !cvar_Enabled.GetBool() )
		{
			amxteleport.Tell( "Teleporting not allowed now.", pPlayer, HUD_PRINTTALK );
			return;
		}

		string msg;
		snprintf( msg, "Your current stats:  %1 saves , %2 loads.", g_Stats[id].x, g_Stats[id].y );

		amxteleport.Tell( msg, pPlayer, HUD_PRINTTALK );

		snprintf( msg, "Current %1 stats: %2 saves, %3 loads.", pPlayer.pev.netname, g_Stats[id].x, g_Stats[id].y );

		for( int i = 1; i <= g_PlayerFuncs.GetNumPlayers(); i++ )
			if( i != id ) amxteleport.Tell( msg, g_PlayerFuncs.FindPlayerByIndex(i), HUD_PRINTTALK );
	}

	void cmdVersion( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		string msg = PLUGNAME + " by Nero\nVersion " + VERSION + "\n(C)2017, Nero(psychotherapist@hotmale.com)";

		HUDTextParams textParms;
		textParms.r1 = 20;
		textParms.g1 = 20;
		textParms.b1 = 180;
		textParms.x = -1.0f;
		textParms.y = 0.05f;
		textParms.effect = 0;
		textParms.fxTime = 6.0f;
		textParms.holdTime = 12.0f;
		textParms.fadeinTime = 0.1f;
		textParms.fadeoutTime = 0.2f;
		textParms.channel = -1;

		g_PlayerFuncs.HudMessage( pPlayer, textParms, msg );
	}

	bool PlayerAllowedToSave( CBasePlayer@ pPlayer )
	{
		int id = pPlayer.entindex();

		if( !cvar_Enabled.GetBool() )
		{
			amxteleport.Tell( "Teleporting currently not allowed.", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( !g_bPlayerAllowed[id] and !AFBase::CheckAccess(pPlayer, ACCESS_T) )
		{
			amxteleport.Tell( "You are not allowed to teleport.", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( !pPlayer.IsAlive() )
		{
			amxteleport.Tell( "You cannot save while dead!", pPlayer, HUD_PRINTTALK );
			return false;
		}
/*Fuck this shit, just leaving it here for completion
		if( pPlayer.pev.movetype == MOVETYPE_NOCLIP or pPlayer.pev.movetype == PLAYER_NOCLIP )
		{
			amxteleport.Tell( "You cannot save while in noclip mode!", pPlayer, HUD_PRINTTALK );
			return false;
		}
*/
		// only players with access ACCESS_TELEPORT can save position while spectator/dead.
		if( /*!pPlayer.IsAlive() or*/ pPlayer.GetObserver().IsObserver() )
		{
			if( !AFBase::CheckAccess(pPlayer, ACCESS_T) )
			{
				//amxteleport.Tell( "You cannot save while being spectator or dead, sorry!", pPlayer, HUD_PRINTTALK );
				amxteleport.Tell( "You cannot save while spectating, sorry!", pPlayer, HUD_PRINTTALK );
				return false;
			}
		}

		if( !AFBase::CheckAccess(pPlayer, ACCESS_T) )
		{
			if( !pPlayer.pev.FlagBitSet(FL_ONGROUND) )
			{
				amxteleport.Tell( "You may not save while in the air!", pPlayer, HUD_PRINTTALK );
				return false;
			}
		}

		return true;
	}

	bool PlayerAllowedToPos( CBasePlayer@ pPlayer )
	{
		int id = pPlayer.entindex();

		if( !cvar_Enabled.GetBool() )
		{
			amxteleport.Tell( "Teleporting currently not allowed.", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( !g_bPlayerAllowed[id] )
		{
			amxteleport.Tell( "You are not allowed to teleport.", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( pPlayer.GetObserver().IsObserver() )
		{
			amxteleport.Tell( "Teleporting not allowed in observer mode!", pPlayer, HUD_PRINTTALK );
			return false;
		}
		
		if( !pPlayer.IsAlive() )
		{
			amxteleport.Tell( "You cannot teleport while dead!", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( (pPlayer.m_afPhysicsFlags & PFLAG_ONBARNACLE) != 0 )
		{
			amxteleport.Tell( "You cannot teleport while grabbed by a Barnacle!", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( !bPosDelayStatus )
			return true;

		if( !AFBase::CheckAccess(pPlayer, ACCESS_T) ) //??
		{
			float flCurTime;
			float flSecsAgo;

			flCurTime = g_Engine.time;

			if( g_flLastTime[id] == 0 )
			{
				g_flLastTime[id] = flCurTime;
				return true;
			}

			flSecsAgo = flCurTime - g_flLastTime[id];

			if( flSecsAgo < g_flPosDelay )
			{
				string msg;
				string seconds = string(g_flPosDelay-flSecsAgo);
				//if( seconds.Length() > 5) seconds = seconds.SubString(0, 5);
				snprintf( msg, "You are not allowed to teleport yet: %1 seconds remaining...", seconds );
				amxteleport.Tell( msg, pPlayer, HUD_PRINTTALK );
				return false;
			}
			else
				g_flLastTime[id] = flCurTime;
		}

		return true;
	}

	bool read_file_( string filename )
	{
		if( amxports.file_exists(filename) ) //remove ??
		{
			File@ file = g_FileSystem.OpenFile( filename, OpenFile::READ );

			if( file !is null and file.IsOpen() )
			{
				int i = 0;
				bool bSuccess = false;

				while( !file.EOFReached() )
				{
					string sLine;
					file.ReadLine(sLine);

					//fix for linux
					string sFix = sLine.SubString( sLine.Length() - 1, 1 );
					if( sFix == " " or sFix == "\n" or sFix == "\r" or sFix == "\t" )
						sLine = sLine.SubString( 0, sLine.Length() - 1 );

					//comment
					if( sLine.SubString(0,1) == "#" or sLine.IsEmpty() )
						continue;

					array<string> parsed = sLine.Split(" ");

					if( parsed.length() < 7 )
						continue;

					g_vecSlot[i] = Vector( atof(parsed[0]), atof(parsed[1]), atof(parsed[2]) );
					g_vecSlotAngle[i] = Vector( atof(parsed[3]), atof(parsed[4]), atof(parsed[5]) );
					g_vecSlotName[i] = parsed[6];

					bSuccess = true;
					i++;
				}

				file.Close();

				if( bSuccess ) return true;
			}
		}

		return false;
	}

	void do_effect( Vector origin )
	{
		int effectnum = cvar_TeleportEffect.GetInt();

		if( effectnum == -1 ) return;

		if( effectnum == 0 or effectnum > NUM_EFFECTS ) effectnum = Math.RandomLong( 1, NUM_EFFECTS-1 );

		switch( effectnum )
		{
			case 1:
			{
				NetworkMessage te1( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te1.WriteByte( TE_TELEPORT );
					te1.WriteCoord( origin.x );
					te1.WriteCoord( origin.y );
					te1.WriteCoord( origin.z );
				te1.End();

				break;
			}

			case 2:
			{
				NetworkMessage te2( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te2.WriteByte( TE_SPARKS );
					te2.WriteCoord( origin.x );
					te2.WriteCoord( origin.y );
					te2.WriteCoord( origin.z + 50 );
				te2.End();

				break;
			}

			case 3:
			{
				NetworkMessage te3( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te3.WriteByte( TE_LAVASPLASH );
					te3.WriteCoord( origin.x );
					te3.WriteCoord( origin.y );
					te3.WriteCoord( origin.z );
				te3.End();

				break;
			}

			case 4:
			{
				NetworkMessage te4( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te4.WriteByte( TE_EXPLOSION2 );
					te4.WriteCoord( origin.x );
					te4.WriteCoord( origin.y );
					te4.WriteCoord( origin.z );
					te4.WriteByte( 1 );//starting color
					te4.WriteByte( 16 );//num colors
				te4.End();

				break;
			}

			case 5:
			{
				NetworkMessage te5( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te5.WriteByte( TE_IMPLOSION );
					te5.WriteCoord( origin.x );
					te5.WriteCoord( origin.y );
					te5.WriteCoord( origin.z );
					te5.WriteByte( 60 );//radius
					te5.WriteByte( 35 );//count
					te5.WriteByte( 15 );//life
				te5.End();

				break;
			}

			case 6:
			{
				NetworkMessage te6( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te6.WriteByte( TE_DLIGHT );
					te6.WriteCoord( origin.x );
					te6.WriteCoord( origin.y );
					te6.WriteCoord( origin.z );
					te6.WriteByte( 40 );//radius
					te6.WriteByte( int(Math.RandomLong(0,255)) );//red
					te6.WriteByte( int(Math.RandomLong(0,255)) );//green
					te6.WriteByte( int(Math.RandomLong(0,255)) );//blue
					te6.WriteByte( 15 );//life
					te6.WriteByte( 20 );//decay
				te6.End();

				break;
			}

			default:
			{
				NetworkMessage te1( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					te1.WriteByte( TE_TELEPORT );
					te1.WriteCoord( origin.x );
					te1.WriteCoord( origin.y );
					te1.WriteCoord( origin.z );
				te1.End();

				break;
			}
		}
	}

	void do_sound( CBasePlayer@ pPlayer, int n )
	{
		g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_STATIC, g_tp_sounds[n], 1, ATTN_NORM );
	}

	/*void msg_show_activity( string adminName, string name )
	{
		switch( amxports::cvar_iAdminShowActivity.GetInt() )
		{
			case 1: g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "ADMIN: " + name + "%s has been teleported.\n" ); break;
			case 2: g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "ADMIN (" + adminName + "): " + name + " has been teleported.\n" ); break;
		}
	}*/

	/******************************************************************************
	 *
	 *	Auto unstucking.
	 *
	 *	From the great NL)Ramon(NL plugin
	 *
	 ******************************************************************************/
	void CheckStuckPlayer( CBasePlayer@ pPlayer )
	{
		Vector origin, mins;
		HULL_NUMBER hull;
		const array<Vector> size = {
			Vector(0.0, 0.0, 1.0), Vector(0.0, 0.0, -1.0), Vector(0.0, 1.0, 0.0), Vector(0.0, -1.0, 0.0), Vector(1.0, 0.0, 0.0), Vector(-1.0, 0.0, 0.0), Vector(-1.0, 1.0, 1.0),Vector(1.0, 1.0, 1.0),Vector(1.0, -1.0, 1.0),Vector(1.0, 1.0, -1.0), Vector(-1.0, -1.0, 1.0), Vector(1.0, -1.0, -1.0), Vector(-1.0, 1.0, -1.0), Vector(-1.0, -1.0, -1.0),
			Vector(0.0, 0.0, 2.0), Vector(0.0, 0.0, -2.0), Vector(0.0, 2.0, 0.0), Vector(0.0, -2.0, 0.0), Vector(2.0, 0.0, 0.0), Vector(-2.0, 0.0, 0.0), Vector(-2.0, 2.0, 2.0), Vector(2.0, 2.0, 2.0), Vector(2.0, -2.0, 2.0), Vector(2.0, 2.0, -2.0), Vector(-2.0, -2.0, 2.0), Vector(2.0, -2.0, -2.0), Vector(-2.0, 2.0, -2.0), Vector(-2.0, -2.0, -2.0),
			Vector(0.0, 0.0, 3.0), Vector(0.0, 0.0, -3.0), Vector(0.0, 3.0, 0.0), Vector(0.0, -3.0, 0.0), Vector(3.0, 0.0, 0.0), Vector(-3.0, 0.0, 0.0), Vector(-3.0, 3.0, 3.0), Vector(3.0, 3.0, 3.0), Vector(3.0, -3.0, 3.0), Vector(3.0, 3.0, -3.0), Vector(-3.0, -3.0, 3.0), Vector(3.0, -3.0, -3.0), Vector(-3.0, 3.0, -3.0), Vector(-3.0, -3.0, -3.0),
			Vector(0.0, 0.0, 4.0), Vector(0.0, 0.0, -4.0), Vector(0.0, 4.0, 0.0), Vector(0.0, -4.0, 0.0), Vector(4.0, 0.0, 0.0), Vector(-4.0, 0.0, 0.0), Vector(-4.0, 4.0, 4.0), Vector(4.0, 4.0, 4.0), Vector(4.0, -4.0, 4.0), Vector(4.0, 4.0, -4.0), Vector(-4.0, -4.0, 4.0), Vector(4.0, -4.0, -4.0), Vector(-4.0, 4.0, -4.0), Vector(-4.0, -4.0, -4.0),
			Vector(0.0, 0.0, 5.0), Vector(0.0, 0.0, -5.0), Vector(0.0, 5.0, 0.0), Vector(0.0, -5.0, 0.0), Vector(5.0, 0.0, 0.0), Vector(-5.0, 0.0, 0.0), Vector(-5.0, 5.0, 5.0), Vector(5.0, 5.0, 5.0), Vector(5.0, -5.0, 5.0), Vector(5.0, 5.0, -5.0), Vector(-5.0, -5.0, 5.0), Vector(5.0, -5.0, -5.0), Vector(-5.0, 5.0, -5.0), Vector(-5.0, -5.0, -5.0)
		};

		if( pPlayer.IsConnected() and pPlayer.IsAlive() )
		{
			origin = pPlayer.pev.origin;
			hull = pPlayer.pev.FlagBitSet(FL_DUCKING) ? head_hull : human_hull;
			if( !is_hull_vacant(origin, hull, pPlayer) and pPlayer.pev.movetype != MOVETYPE_NOCLIP and pPlayer.pev.solid != SOLID_NOT )
			{
				mins = pPlayer.pev.mins;
				Vector vec;
				vec.z = origin.z;
				for( uint ofs = 0; ofs < size.length(); ++ofs )
				{
					vec.x = origin.x - mins.x * size[ofs].x;
					vec.y = origin.y - mins.y * size[ofs].y;
					vec.z = origin.z - mins.z * size[ofs].z;
					if( is_hull_vacant(vec, hull, pPlayer) )
					{
						pPlayer.SetOrigin( vec );
						ofs = size.length();
					}
				}
			}
		}
	}

	void checkstuck()
	{
		CBasePlayer@ pPlayer;

		if( cvar_AutoUnstuck.GetBool() )
		{
			for( int i = 1; i <= g_Engine.maxClients; ++i )
			{
				@pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

				if( pPlayer !is null )
					CheckStuckPlayer( pPlayer );
			}

			@AMXTeleport::g_pCheckStuck = g_Scheduler.SetTimeout( "checkstuck", 0.1f );
		}
		else
			@AMXTeleport::g_pCheckStuck = g_Scheduler.SetTimeout( "checkstuck", 1.5f );
	}

	bool is_hull_vacant( Vector origin, HULL_NUMBER hull, CBasePlayer@ pPlayer )
	{
		TraceResult tr;
		g_Utility.TraceHull( origin, origin, ignore_monsters, hull, pPlayer.edict(), tr );//dont_ignore_monsters makes you bob up and down on placed corpses

		if( tr.fStartSolid != 1 or tr.fAllSolid != 1 )
			return true;
		
		return false;
	}
}

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		May 24 2018
*	-------------------------
*	- First Release
*	-------------------------
*/
