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
		this.ExpansionName = "AMX Teleportation Commands";
		this.ShortName = "AMXTC";
	}

	void ExpansionInit()
	{
		//new efstr[100]
		//formatex(efstr, 99, "- [n]: get/set teleporting effect ([0,%d], 0 = random).", NUM_EFFECTS)

		RegisterCommand( "amxtc_tpstack", "s", "(target) - stack player(s) on you.", AFBase::ACCESS_H, @AMXTeleport::TPStack );
		//register_concmd("amxtc_tpallow", "amxtc_tpallow", ACCESS_ADMIN,  "- [on|off|0|1]: enable/disable teleporting.")
		RegisterCommand( "amxtc_tpallowuser", "ss", "(target) ('on'|'1'|'off'|'0') - enable/disable teleporting for target.", AFBase::ACCESS_H, @AMXTeleport::TPAllowUser );
		/*register_concmd("amxtc_tpeffect", "amxtc_tpeffect", ACCESS_TELEPORT, efstr)
		register_concmd("amxtc_tpempty","amxtc_tpempty",ACCESS_TELEPORT,": remove all positions in list.")*/
		//RegisterCommand( "amxtc_tpadd", "s", "(target) - add targets position in first free slot.", AFBase::ACCESS_H, @AMXTeleport::TPAdd );
		/*register_concmd("amxtc_tpmem","amxtc_tpmem",ACCESS_TELEPORT,"- <target> <Slot_num>: memorize target position in a slot.")
		register_concmd("amxtc_tp","amxtc_tp",ACCESS_TELEPORT,"- <target> <Slot_num | Slot_name>: teleport target from a g_vecSlots.")
		register_concmd("amxtc_tpgo","amxtc_tpgo",ACCESS_TELEPORT,"- <target> <x> <y> <z>: teleport target to coordinates.")
		register_concmd("amxtc_tplist","amxtc_tplist",ACCESS_TELEPORT,": display memorised positions.")
		register_concmd("amxtc_tpload","amxtc_tpload",ACCESS_TELEPORT,": load positions from file.")
		register_concmd("amxtc_tpsave","amxtc_tpsave",ACCESS_TELEPORT,": save positions to file.")
		register_concmd("amxtc_tpname","amxtc_tpname",ACCESS_TELEPORT,"- <Slot_num> [Slot_name]: name or unname a slot.")
		register_concmd("amxtc_tpcopy","amxtc_tpcopy",ACCESS_TELEPORT,"- <user> <target>: copy the user position to target.")*/
		//RegisterCommand( "amxtc_tpsend", "ss", "(user) (target) - stack user on target.", AFBase::ACCESS_H, @AMXTeleport::TPSend );
		RegisterCommand( "amxtc_tpaim", "s", "(target) - send player(s) to where you're looking.", AFBase::ACCESS_H, @AMXTeleport::TPAim );
		//RegisterCommand( "amxtc_tpdelay", "f", "(delay) - set a delay between 2 posme (0 = OFF).", AFBase::ACCESS_H, @AMXTeleport::TPDelay );
		//RegisterCommand( "amxtc_tpinfo", "", " - display the current position coordinates.", AFBase::ACCESS_H, @AMXTeleport::TPInfo );
		RegisterCommand( "player_clearteleports", "s", "(target) - resets any saved positions of targetted player(s).", AFBase::ACCESS_H, @AMXTeleport::TPClear );

		RegisterCommand( "say saveme", "", "- saves your position into slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdSaveme, false, true );
		RegisterCommand( "say /s", "", "- saves your position into slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdSaveme, false, true );
		RegisterCommand( "say saveme2", "", "- saves your position into slot 2", AFBase::ACCESS_Z, @AMXTeleport::cmdSaveme2, false, true );
		RegisterCommand( "say posme", "", "- loads your position from slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdPosme, false, true );
		RegisterCommand( "say /t", "", "- loads your position from slot 1", AFBase::ACCESS_Z, @AMXTeleport::cmdPosme, false, true );
		RegisterCommand( "say posme2", "", "- loads your position from slot 2", AFBase::ACCESS_Z, @AMXTeleport::cmdPosme2, false, true );
		RegisterCommand( "say /stats", "", "- displays checkpoint stats.", AFBase::ACCESS_Z, @AMXTeleport::cmdStats, false, true );
		RegisterCommand( "say /teleport_version", "", "", AFBase::ACCESS_Z, @AMXTeleport::cmdVersion, false, true );

		@AMXTeleport::g_bTeleport = CCVar( "amxtc_enabled", 1, "Enable/disable teleport plugin. (default: 1)", ConCommandFlag::AdminOnly );
		@AMXTeleport::g_iTeleportEffect = CCVar( "amxtc_teleporteffect", 1, "Get/set teleporting effect (<0-6>, 0 = random). (default: 1)", ConCommandFlag::AdminOnly );
		@AMXTeleport::g_bUnstuck = CCVar( "amxtc_autounstuck", 1, "Enable/disable auto-unstuck. (default: 1)", ConCommandFlag::AdminOnly );

		g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @AMXTeleport::ClientPutInServer );

		// empty and load list (if file exists) at map change automatically
		for( uint i = 0; i < AMXTeleport::NUMSLOTS; i++ )
		{
			//formatex(g_slot_name[i], MAX_TEXT_LENGTH, "pos%i", i+1)
			AMXTeleport::g_vecSlots[i].x = AMXTeleport::g_vecSlots[i].y = AMXTeleport::g_vecSlots[i].z = -1;
		}
/*
		new map[MAX_TEXT_LENGTH], cfgdir[MAX_TEXT_LENGTH]
		get_mapname(map, MAX_TEXT_LENGTH-1)
		get_configsdir(cfgdir, MAX_TEXT_LENGTH)
		formatex(g_cfgfilepath, MAX_TEXT_LENGTH-1, "%s/pos", cfgdir)
		if (!dir_exists(g_cfgfilepath)) {
			mkdir(g_cfgfilepath)
		}
		formatex(g_cfgfilepath, MAX_TEXT_LENGTH-1, "%s/pos/%s.pos", cfgdir, map)
		read_file_(g_cfgfilepath)
*/
		if( AMXTeleport::g_pCheckStuck !is null )
			g_Scheduler.RemoveTimer( AMXTeleport::g_pCheckStuck );

		@AMXTeleport::g_pCheckStuck = g_Scheduler.SetTimeout( "checkstuck", 0.1f );
	}

	void MapInit()
	{
		AMXTeleport::g_DisabledMaps.resize(0);
		AMXTeleport::ReadMapsFile();
		//Aperture
		AMXTeleport::g_bTeleport.SetInt(1);

		//loop through the disabled map list
		for( uint i = 0; i < AMXTeleport::g_DisabledMaps.length(); i++ )
		{
			if( g_Engine.mapname == AMXTeleport::g_DisabledMaps[i] )
			{
				//g_Game.AlertMessage( at_logged, "[AMXTC] Disabled map detected!\n" );
				AMXTeleport::g_bTeleport.SetInt(0);
				break;
			}
		}
		//Aperture

		//if( g_EngineFuncs.NumberOfEntities() < g_Engine.maxEntities - 15*g_Engine.maxClients - 2 )
		for( uint i=0; i<3; i++ )
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
	const string VERSION = "2.0";

	const uint NUMSLOTS = 40;
	const int NUM_EFFECTS = g_effects.length();

	array<string> g_DisabledMaps;

	array<Vector2D> g_Stats(33);
	array<bool> g_bPlayerAllowed(33);
	array<Vector> g_vecUserSlot(33);
	array<Vector> g_vecUserSlot2(33);
	array<Vector> g_vecUserSlotAngle(33);
	array<Vector> g_vecUserSlotAngle2(33);
	array<float> g_flLastTime(33);

	bool bPosDelayStatus = true; // teleport delay is ON by default
	float flPosDelay = 2.0f; // delay = 2 secs

	CCVar@ g_bTeleport;
	CCVar@ g_iTeleportEffect;
	CCVar@ g_bUnstuck;

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
	array<Vector> g_vecSlots(NUMSLOTS);
	string g_NoTeleportFile = "scripts/plugins/AFBaseExpansions/amxports/configs/plugin_teleport/noteleport.txt";

	HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
	{
		int id = pPlayer.entindex();
		g_bPlayerAllowed[id] = true;
		g_flLastTime[id] = 0;
		g_Stats[id].x = g_Stats[id].y = 0;

		return HOOK_CONTINUE;
	}

	void ReadMapsFile()
	{
		File@ file = g_FileSystem.OpenFile(g_NoTeleportFile, OpenFile::READ);

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

				g_DisabledMaps.insertLast(sLine);
			}

			file.Close();
		}
	}

	/*****************************************************************************************
	*
	*	amxtc_tpadd
	*
	*       syntax:
	*       amxtc_tpadd target              add target position to list
	*       amxtc_tpadd                    add command-user position to list
	*
	******************************************************************************************/
	/*void TPAim( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), TARGETS_NOALL|TARGETS_NOIMMUNITYCHECK, pTargets) )
		{
			CBasePlayer@ pTarget;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				new userName[MAX_NAME_LENGTH]
				new origin[3], i
				new Float:angles[3], iangles[3]
				
				get_user_name(user, userName, MAX_NAME_LENGTH-1)
				get_user_origin(user, origin)
				pev(user, pev_angles, angles)
				FVecIVec(angles, iangles)
				for (i=0; i<NUMSLOTS; i++)
				{
					if( g_vecSlots[i][0] == -1 and g_vecSlots[i][1] == -1 and g_vecSlots[i][2] == -1 )
					{
						g_vecSlots[i][0] = origin[0]
						g_vecSlots[i][1] = origin[1]
						g_vecSlots[i][2] = origin[2]
						g_slot_angle[i][0] = iangles[0]
						g_slot_angle[i][1] = iangles[1]
						g_slot_angle[i][2] = iangles[2]
						console_print(id, "Success : player %s's position added in slot #%d.", userName, i+1)
						return PLUGIN_HANDLED;
					}
				}
			}

			amxteleport.Tell( "Successfully teleported target(s)", pAdmin, HUD_PRINTCONSOLE );
		}

		amxteleport.Tell( "No more slot available!", pAdmin, HUD_PRINTCONSOLE );
	}*/

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
					pTarget.SetOrigin(tr.vecEndPos+Vector(0,0,38));
					pTarget.pev.angles = angles;
					pTarget.pev.fixangle = FAM_FORCEVIEWANGLES;
				}
			}

			amxteleport.Tell( "Successfully teleported target(s)", pAdmin, HUD_PRINTCONSOLE );
		}
	}

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
	*	amxtc_tpallowuser
	*
	*       syntax:
	*       amxtc_tpallowuser #user flag           flag: 'on' | 'off' | '0'| '1'
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
					amxteleport.Tell( "Player " + pTarget.pev.netname + " can now teleport himself.", pAdmin, HUD_PRINTCONSOLE );
				}
				else
				{
					g_bPlayerAllowed[id] = false;
					amxteleport.Tell( "Player " + pTarget.pev.netname + " is now unable to teleport himself.", pAdmin, HUD_PRINTCONSOLE );
				}
			}
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
	/*
	public amxtc_tpinfo(id, level, cid) {
		if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
		new origin[3]
		
		get_user_origin(id, origin)
		console_print(id, "Your position is: X = %d, Y = %d, Z = %d.", origin[0], origin[1], origin[2])
		return PLUGIN_HANDLED
	}
	*/
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

	void cmdStats( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		int id = pPlayer.entindex();

		if( !g_bTeleport.GetBool() )
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

		if( !g_bTeleport.GetBool() )
		{
			amxteleport.Tell( "Teleporting currently not allowed.", pPlayer, HUD_PRINTTALK );
			return false;
		}

		if( !g_bPlayerAllowed[id] and g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES )
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
			if( g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES )
			{
				//amxteleport.Tell( "You cannot save while being spectator or dead, sorry!", pPlayer, HUD_PRINTTALK );
				amxteleport.Tell( "You cannot save while being spectator, sorry!", pPlayer, HUD_PRINTTALK );
				return false;
			}
		}

		return true;
	}

	bool PlayerAllowedToPos( CBasePlayer@ pPlayer )
	{
		int id = pPlayer.entindex();

		if( !g_bTeleport.GetBool() )
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

		if( g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES )
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

			if( flSecsAgo < flPosDelay )
			{
				string msg;
				snprintf( msg, "You are not allowed to teleport yet: %1 seconds remaining...", flPosDelay-flSecsAgo );
				amxteleport.Tell( msg, pPlayer, HUD_PRINTTALK );
				return false;
			}
			else
				g_flLastTime[id] = flCurTime;
		}

		return true;
	}

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

		if( g_bUnstuck.GetBool() )
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

	void do_effect( Vector origin )
	{
		int effectnum = g_iTeleportEffect.GetInt();

		if( effectnum == 0 ) return;

		if( effectnum > NUM_EFFECTS ) effectnum = Math.RandomLong( 1, NUM_EFFECTS );

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
		}
	}

	void do_sound( CBasePlayer@ pPlayer, int n )
	{
		g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_STATIC, g_tp_sounds[n], 1, ATTN_NORM );
	}

	void TPClear( AFBaseArguments@ args )
	{
		CBasePlayer@ pAdmin = args.User;
		array<CBasePlayer@> pTargets;

		if( AFBase::GetTargetPlayers(pAdmin, HUD_PRINTCONSOLE, args.GetString(0), 0, pTargets) )
		{
			CBasePlayer@ pTarget;

			for( uint i = 0; i < pTargets.length; i++ )
			{
				@pTarget = pTargets[i];

				if( pTarget !is null )
				{
					int id = pTarget.entindex();
					g_vecUserSlot[id] = Vector(-1, -1, -1);
					g_vecUserSlot2[id] = Vector(-1, -1, -1);
					g_vecUserSlotAngle[id] = Vector(-1, -1, -1);
					g_vecUserSlotAngle2[id] = Vector(-1, -1, -1);
				}
			}

			amxteleport.Tell( "Successfully cleared target teleport(s).", pAdmin, HUD_PRINTCONSOLE );
		}
	}
}

/*
*	Changelog
*
*	Version: 	1.9
*	Date: 		June 18 2017
*	-------------------------
*	- Added this changelog
*	- Added the command .player_clearteleports
*	-------------------------
*
*	Version: 	2.0
*	Date: 		August 24 2017
*	-------------------------
*	- Plugin now reads a list of maps that have teleporting disabled on them
*	-------------------------
*/
