/*****************************************************************************************
* Dynamicly(sic) Loaded Player Glows, by Fire-Wired
* Ported to Angelscript and AFBase by Nero @ Svencoop Forums
*****************************************************************************************/
DynamicGlow dynamicglow;

array<CScheduledFunction@> m_pDynamicGlowThink(33);

void DynamicGlow_Call()
{
	dynamicglow.RegisterExpansion( dynamicglow );
}

class DynamicGlow : AFBaseClass
{

	void ExpansionInfo()
	{
		this.AuthorName = "Nero";
		this.ExpansionName = "AMX Dynamically Loaded Player Glows";
		this.ShortName = "AMXDG";
	}

	void ExpansionInit()
	{
		//RegisterCommand( "amxdg_reloadglows", "", "Reload glow-colors", AFBase::ACCESS_E, @DynamicGlow::LoadGlows );
		RegisterCommand( "say glow", "s", "help for a list of commands.", AFBase::ACCESS_Z, @DynamicGlow::cmdGlow, false, true );

		g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, @DynamicGlow::PlayerSpawn );
	}

	void MapInit()
	{
		DynamicGlow::g_GlowColors.deleteAll();
		DynamicGlow::LoadGlows();
	}

	void ClientDisconnectEvent( CBasePlayer@ pPlayer )
	{
		DynamicGlow::glow_off( pPlayer, false, false );
	}

	void StopEvent()
	{
		for( int i = 0; i <= g_Engine.maxClients; ++i )
		{
			if( m_pDynamicGlowThink[i] !is null )
			{
				g_Scheduler.RemoveTimer( m_pDynamicGlowThink[i] );
				@m_pDynamicGlowThink[i] = null;
			}
		}

		DynamicGlow::g_PlayerGlows.deleteAll();
		DynamicGlow::g_GlowColors.deleteAll();
	}

	void StartEvent()
	{
		DynamicGlow::g_GlowColors.deleteAll();
		DynamicGlow::LoadGlows();
	}
}

namespace DynamicGlow
{

const int MAXGLOWS = 3000; // hard coded limit on number of glows
const int MAXGLOWLIST = 40; // DO NOT EDIT - defines max glows to list in motd window, more than 50 will overflow client!  This controls pagination
const string VERSION = "1.3";
const string LASTUPDATE = "January 07 2018";
const string g_Filename = "scripts/plugins/AFBaseExpansions/amxports/glows.cfg"; // stores the location of the glows.cfg file

//new bool:g_safe_removal = true     // defines if removal means overwriting the glow or commenting it out
int g_iTotalGlows = 0; // Stores how many glows have been read from glow.cfg
dictionary g_GlowColors;
dictionary g_PlayerGlows;
array<int> g_iStrobing(33);
//new bool:g_config_safe_remove

class GlowData
{
	string sName;
	string sMode;
	string sAmount;
	string sFx;
	string sRed;
	string sGreen;
	string sBlue;
	string sSteamid;
	string sDescription;
}

void cmdGlow( AFBaseArguments@ args )
{
	CBasePlayer@ pPlayer = args.User;
	if( pPlayer is null ) return;

	int id = pPlayer.entindex();
	bool bHideChat = false;

	string message = "";
	for( uint i = 1; i < args.RawArgs.length(); ++i )
	{
		if( i > 1 ) message += " ";

		message += args.RawArgs[i];
	}

	if( g_iTotalGlows == 0 )
		LoadGlows();

	if( message.Find("reload") != Math.SIZE_MAX )
	{
		if( AFBase::CheckAccess(pPlayer, ACCESS_E) )
		{
			g_iTotalGlows = -1; // identifier to prevent player from trying glow during reload
			LoadGlows();
			dynamicglow.Tell( "reloaded " + g_iTotalGlows + " glows", pPlayer, HUD_PRINTTALK );
		}
		else
			dynamicglow.Tell( "you don't have access to this command!", pPlayer, HUD_PRINTTALK );
	}
	else if( message.Find("help") != Math.SIZE_MAX )
		glow_display_help(id);
	// because of the nature of these functions they can be grouped together for efficiency, and because I run out of stack space if they are separate :-/
	/*else if( containi(message, "add") == 0 || containi(message, "edit") == 0 || containi(message, "remove") == 0 || containi(message, "render") == 0 )
	{
		if( AFBase::CheckAccess(pPlayer, ACCESS_E) and !is_reloading() and message.Length() > 0 )
			modify_glow_config( id, message );
		else
			dynamicglow.Tell( "you don't have access to this command!", pPlayer, HUD_PRINTTALK );
	}*/
	else if( message.Find("list") != Math.SIZE_MAX )
	{
		if( !is_reloading() )
		{
			bHideChat = true;
			message.Replace( "list", "" );
			message.Trim();
			list_glows( id, message );
		}
	}
	else if( message.Find("display") != Math.SIZE_MAX )
	{
		if( !is_reloading() )
		{
			bHideChat = true;
			message.Replace( "display", "" );
			message.Trim();
			display_glow( id, message );
		}
	}
	else if( message.Find("random") != Math.SIZE_MAX and message.Length() > 7 )
	{
		if( !is_reloading() )
			set_glow_random( id, message );
	}
	else if( message.Find("off") != Math.SIZE_MAX )
		glow_off(pPlayer);
	else
	{
		if( !is_reloading() and message.Length() > 0 )
			client_glow( pPlayer, message );
	}

	if( !bHideChat )
	{
		string sOutput = "";
		for( uint i = 0; i < args.RawArgs.length(); ++i )
		{
			if( i > 0 ) sOutput += " ";

			sOutput += args.RawArgs[i];
		}

		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, " " + pPlayer.pev.netname + ": " + sOutput + "\n" );
	}
}

void LoadGlows(/* AFBaseArguments@ args = null */)
{
   // reset global var totalglows, if you run this function it means all data will be overwritten
	DynamicGlow::g_GlowColors.deleteAll();
	g_iTotalGlows = 0;
	bool in_comment = false;

   // check mode safe remove is in from config cvar
   /*if( get_cvar_num("amx_glow_safe_remove") == 0 ) {
     g_config_safe_remove = false
   } else {
     g_config_safe_remove = true
   }*/

	File@ file = g_FileSystem.OpenFile( g_Filename, OpenFile::READ );

	if( file is null or !file.IsOpen() )
	{
		//log_amx("[AMXX Glows] %s file not found, custom glows could not be loaded.",g_Filename)
		g_Game.AlertMessage( at_logged, "[AMXDG DEBUG] %1 file not found, custom glows could not be loaded.\n", g_Filename );
	}
	else
	{
		while( !file.EOFReached() and g_iTotalGlows < MAXGLOWS )
		{
			string sLine;
			file.ReadLine( sLine );
			if( sLine.SubString(sLine.Length()-1,1) == " " or sLine.SubString(sLine.Length()-1,1) == "\n" or sLine.SubString(sLine.Length()-1,1) == "\r" or sLine.SubString(sLine.Length()-1,1) == "\t" )
				sLine = sLine.SubString( 0, sLine.Length()-1 );

			if( sLine.SubString(0,1) == "#" or sLine.SubString(0,1) == ";" or sLine.SubString(0,2) == "//" or sLine.IsEmpty() )
				continue;

			if( containi(sLine, "*/") >= 0 and in_comment ) // end of multi line comment
			{//sLine.SubString(0, 2) == "*/"
				//g_Game.AlertMessage( at_console, "[AMXDG DEBUG] Comment end: %1\n", sLine );
				in_comment = false;
				continue;
			}
			else if( containi(sLine, "/*") == 0 and !in_comment ) // beginning of multi line comment
			{//sLine.SubString(0, 2) == "/*"
				//g_Game.AlertMessage( at_console, "[AMXDG DEBUG] Comment start: %1\n", sLine );
				in_comment = true;
				continue;
			}
			else if( !in_comment )
			{
				array<string> parsed = sLine.Split("\""); //separate the comment from the rest
				if( parsed.length() < 2 )
					continue;

				array<string> parsed2 = parsed[0].Split(" ");

				if( parsed2.length() < 8 and parsed[1].IsEmpty() )
					continue;

				GlowData pData;
				string sName = parsed2[0].ToLowercase();
				pData.sName = sName;
				pData.sMode = parsed2[1];
				pData.sAmount = parsed2[2];
				pData.sFx = parsed2[3];
				pData.sRed = parsed2[4];
				pData.sGreen = parsed2[5];
				pData.sBlue = parsed2[6];
				pData.sSteamid = parsed2[7];
				pData.sDescription = parsed[1];

				g_GlowColors[sName] = pData;
				++g_iTotalGlows;
			}
			else continue;
				//g_Game.AlertMessage( at_console, "[AMXDG DEBUG] In comment: %1\n", sLine );
		}

		file.Close();

		g_Game.AlertMessage( at_logged, "[AMXDG] loaded %1 glows from config file\n", g_iTotalGlows );
	}
}

void glow_display_help( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "===================================================================\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Dynamic Glow Plugin - Version: " + VERSION + " - Last Update: " + LASTUPDATE + "\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "===================================================================\n\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Basic Glow Commands:\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  1. say ''glow <color>'' to glowing a color.\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  2. say ''glow off'' to stop glowing.\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  3. say ''glow list <page #> to search a available color.\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  4. say ''glow display <color>'' to show certain color's detail.\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n\nRandomStyle Glowing Commands: (You can have a color changing glow)\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n  say ''glow random <Random Style> <delay>'' to use a RandomStyle glowing.\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  say ''glow random off'' to stop RandomStyle glowing.\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n  List of <Random Style> :\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n    basic1, basic2, basic3, basic4\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "    trans1, trans2, trans3, trans4\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "    bright1, bright2, bright3, bright4\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n\nSpecial glows:\n" );
	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n    fire, police, xmas, rainbow\n" );

	/*if( AFBase::CheckAccess(pPlayer, ACCESS_C) )
	{
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\n\nAdmin Commands:\n\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  1. say ''glow add <name> <mode> <amount> <fx> <r> <g> <b> <protect 0|1> \n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  \"Description\"'' to add new color.\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  2. say ''glow edit <name> <mode> <amount> <fx> <r> <g> <b> <protect 0|1> \n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  \"Description\"'' to edit a color.\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  3. say ''glow remove <color>'' to remove a color from glow list.\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "  4. say ''glow render <mode> <amount> <fx> <r> <g> <b>'' to use a custom glowing.\n" );
	}*/

	g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "===================================================================\n\n" );

	dynamicglow.Tell( "Glow help has been printed in the console! (tilde-key on US keyboards)\n", pPlayer, HUD_PRINTTALK );
}

void glow_off( CBasePlayer@ pPlayer, bool bTellPlayer = true, bool bResetRendermode = true )
{
	if( pPlayer is null )
	{
		g_Game.AlertMessage( at_logged, "[AMXDG DEBUG] pPlayer is null at glow_off(null, %1, %2)\n", bResetRendermode, bTellPlayer );
		return;
	}

	string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));
	int id = pPlayer.entindex();

	if( g_PlayerGlows.exists(sFixId) )
		g_PlayerGlows.delete(sFixId);

	if( m_pDynamicGlowThink[id] !is null )
	{
		g_Scheduler.RemoveTimer( m_pDynamicGlowThink[id] );
		@m_pDynamicGlowThink[id] = null;
	}

	if( bResetRendermode )
		amxports.set_user_rendering( id, 0, 0, 0, 0, 0, 100 );

	if( bTellPlayer )
		dynamicglow.Tell( "Glowing Off\n", pPlayer, HUD_PRINTTALK );
}

void display_glow( const int &in id, string glow_name )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	if( g_GlowColors.exists(glow_name.ToLowercase()) )
	{
		GlowData@ pData = cast<GlowData@>(g_GlowColors[glow_name.ToLowercase()]);
		dynamicglow.Tell( string(pData.sName) + " " + 
								 pData.sMode + " " + 
								 pData.sAmount + " " + 
								 pData.sFx + " " + 
								 pData.sRed + " " + 
								 pData.sGreen + " " + 
								 pData.sBlue + " " + 
								 pData.sSteamid + " " + 
								 pData.sDescription,
		pPlayer, HUD_PRINTTALK );
	}
	else
		dynamicglow.Tell( "\"" + glow_name + "\" glow not found!", pPlayer, HUD_PRINTTALK );
}

void modify_glow_config( const int &in id, string message )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;
/*
   new write_text[129]
   new linenum = 0, rawline[129], textlen, raw_glow[128], tmp_right[128], bool:found = false, bool:in_comment = false, bool:is_valid = false
*/
	string glow, command, description;
	int prev_totalglows, mode, amount, fx, red, green, blue, protect;

	if( containi(message, "remove") == 0 )
	{
		prev_totalglows = g_iTotalGlows;	// save total glows
		g_iTotalGlows = -1;					// we can't have people glowing during remove procedure
	}

	message.Trim();
	array<string> parsed = message.Split(" ");

	if( parsed.length() < 1 )
		return;

	command = parsed[0];

	string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

	///////////////////////////////////////////////////////////////////////////////
	// This next set of if's gets the proper parameters for each type of command //
	///////////////////////////////////////////////////////////////////////////////
	if( (containi(command, "add") == 0 or containi(command, "remove") == 0 or containi(command, "edit") == 0) and parsed.length() > 2 )
		glow = parsed[1];

	if( (containi(command, "add") == 0 or containi(command, "edit") == 0) and parsed.length() == 10 )
	{
		mode = atoi(parsed[2]);
		amount = atoi(parsed[3]);
		fx = atoi(parsed[4]);
		red = atoi(parsed[5]);
		green = atoi(parsed[6]);
		blue = atoi(parsed[7]);
		protect = atoi(parsed[8]);
		description = parsed[9];
	}
	else if( containi(command, "render") == 0 and parsed.length() == 7 )
	{
		mode = atoi(parsed[1]);
		amount = atoi(parsed[2]);
		fx = atoi(parsed[3]);
		red = atoi(parsed[4]);
		green = atoi(parsed[5]);
		blue = atoi(parsed[6]);
	}

	/////////////////////////////////////////////
	// Time to validate each of the parameters //
	/////////////////////////////////////////////
	if( containi(command, "render") == 0 ) // only clients with flag T can use render
	{
		if( mode >= 0 and mode <= 5 and amount >= 0 and amount <= 200 and fx >= 0 and fx <= 20 and red >= 0 and red <= 255 and green >= 0 and green <= 255 and blue >= 0 and blue <= 255 )
		{
			amxports.set_user_rendering( id, fx, red, green, blue, mode, amount );
			dynamicglow.Tell( "Custom Rendering Enabled\n", pPlayer, HUD_PRINTTALK );
		}
		else
		{
			dynamicglow.Tell( "Invalid Render Syntax!\n", pPlayer, HUD_PRINTTALK );
			dynamicglow.Tell( "Syntax: glow render <mode 1-5> <amount 1-200> <fx 0-20> <red 0-255> <green 0-255> <blue 0-255>\n", pPlayer, HUD_PRINTTALK );
		}
	}
	else if( containi(command, "add") == 0 || containi(command, "edit") == 0 )
	{
		if( glow.Length() > 0 and mode >= 0 and mode <= 5 and mode != 3 and amount >= 0 and amount <= 200 and fx >= 0 and fx <= 20 and red >= 0 and red <= 255 and green >= 0 and green <= 255 and blue >= 0 and blue <= 255 and protect >= 0 and protect <= 1 and description.Length() > 0 )
		{/*
			if(str_to_num(protect) == 1)
			{
				format(write_text, 128, "%s %s %s %s %s %s %s %s %s ",name, mode, amount, fx, red, green, blue, sFixId, description)
			}
			else
			{
				format(write_text, 128, "%s %s %s %s %s %s %s 0 %s ",name, mode, amount, fx, red, green, blue, description)
			}

			if( containi(command, "add") == 0 )
			{
				write_file( g_filename, write_text, -1 )  // append glow to glow.cfg file
				client_print( id, print_chat, "[Glow] %s glow added to glow.cfg Successfuly!", name )
			}
			else if( containi(command, "edit") == 0 )
			{
				if( find_glow(glow) == -1 )
					client_print( id, print_chat, "[Glow] can't edit %s it does not exist, try adding it first.", glow)
				else
					is_valid = true
			}*/
		}
		else
		{
			if( containi(command, "add") == 0 )
			{
				dynamicglow.Tell( "Invalid Add Syntax!\n", pPlayer, HUD_PRINTTALK );
				dynamicglow.Tell( "Syntax is glow add <name> <mode> <amount> <fx> <red> <green> <blue> <protect> \"description\"\n", pPlayer, HUD_PRINTTALK );
			}
			else if( containi(command, "edit") == 0 )
			{
				dynamicglow.Tell( "Invalid Edit Syntax!\n", pPlayer, HUD_PRINTTALK );
				dynamicglow.Tell( "Syntax is glow edit <glow to edit> <mode> <amount> <fx> <red> <green> <blue> <protect> \"description\"\n", pPlayer, HUD_PRINTTALK );
			}
		}
	}
/*
   if( containi(command, "edit") == 0 && is_valid || containi(command, "remove") == 0 )
   {
      while( read_file(g_filename, linenum, rawline, 128, textlen) && !found )
      {
         strtok(rawline, raw_glow, 64, tmp_right, 128, ' ', 1)  // have to tokenize since comparing rawline won't work
         
         if (strfind(rawline,"*temp/",false) >= 0 && in_comment)  // end of multi line comment
         {
            in_comment = false
         }
         else if (strfind(rawline,"/*",false) == 0 && !in_comment)  // beginning of multi line comment
         {
            in_comment = true
         }
         else if( strcmp(glow,raw_glow, true) == 0 && !in_comment && !(strfind(rawline,"//",false) == 0) && !(strfind(rawline,";",false) == 0)  )
         {
            if( containi(command, "remove") == 0 )
            {
               if(g_config_safe_remove)             // added support for safe removal incase you want to still keep the glow
               {
                  format(write_text,128, "// %s", rawline)
               } else                         //  else just remove that crazy glow from file
               {
                  format(write_text,32,"// Admin Removed Glow [%s]",glow)
               }
               write_file( g_filename, write_text, linenum )
               client_print(id, print_chat, "[Glow] %s has been succssfuly removed!", glow)
            }
            else if( containi(command, "edit") == 0 && is_valid)
            {
               write_file( g_filename, write_text, linenum )  // write edited glow to config file replacing previous
               client_print( id, print_chat, "[Glow] %s glow has been edited Successfuly!", glow )
            }
            found = true
         }
         linenum++
      }   
      if(!found) 
      {
         client_print(id, print_chat, "[Glow] %s was not found in glows.cfg", glow)
      }
   }
*/
	if( containi(command, "remove") == 0 )
	g_iTotalGlows = prev_totalglows; //restore glows count
}

void list_glows( const int &in id, string message )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int page, start, end, total_pages;

	if( message.Length() == 0 )
		page = 1;
	else
	{
		message.Trim();
		page = atoi(message);
	}

	start = ((page * MAXGLOWLIST) - MAXGLOWLIST);
	end = start + MAXGLOWLIST;

	if( g_iTotalGlows % MAXGLOWLIST != 0 )
		total_pages = ((g_iTotalGlows / MAXGLOWLIST) + 1);
	else
		total_pages = (g_iTotalGlows / MAXGLOWLIST);

	if( page <= total_pages ) // check to make sure we are within range
	{
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "===================================================================\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Available Glows: " + g_iTotalGlows + " Glows - Page " + page + " of " + total_pages + "\nto access other pages say ''glow list <page number>''\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "===================================================================\n" );

		array<string> glowNames = g_GlowColors.getKeys();

		for( int i = start; i < g_iTotalGlows and i < end; ++i )
		{
			GlowData@ pData = cast<GlowData@>(g_GlowColors[glowNames[i]]);

			if( pData.sSteamid == "0" )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, string(pData.sName) + " - public - " + pData.sDescription + "\n" );
			else
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, string(pData.sName) + " - private - " + pData.sDescription + "\n" );
		}

		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "===================================================================\n" );

		dynamicglow.Tell("List of glows has been printed in the console! (tilde-key on US keyboards)\n", pPlayer, HUD_PRINTTALK );
	}
	else
		dynamicglow.Tell( "Sorry there are only " + total_pages + " page(s), not " + page + " page(s)\n", pPlayer, HUD_PRINTTALK );
}

void client_glow( CBasePlayer@ pPlayer, string glow_name )
{
	if( pPlayer is null ) return;

	string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));
	int id = pPlayer.entindex();

    bool bIsRandom = false;

	if( glow_name == "fire" or glow_name == "police" or glow_name == "xmas" or glow_name == "rainbow" )
		set_glow_timed( id, glow_name );
	else if( g_GlowColors.exists(glow_name.ToLowercase()) )
	{
		GlowData@ pData = cast<GlowData@>(g_GlowColors[glow_name.ToLowercase()]);

		// set values for rendering, so we can check for random char
		string mode = pData.sMode;
		string amount = pData.sAmount;
		string fx = pData.sFx;
		string red = pData.sRed;
		string green = pData.sGreen;
		string blue = pData.sBlue;

		// ok now lets check the cvars for random char
		if( mode == "r" )
		{
			mode = Math.RandomLong(0, 5);
			bIsRandom = true;
		}

		if( amount == "r" )
		{
			amount = Math.RandomLong(50, 255);
			bIsRandom = true;
		}

		if( fx == "r" )
		{
			fx = Math.RandomLong(0, 20);
			bIsRandom = true;
		}

		if( red == "r" )
		{
			red = Math.RandomLong(1, 255);
			bIsRandom = true;
		}

		if( green == "r" )
		{
			green = Math.RandomLong(1, 255);
			bIsRandom = true;
		}

		if( blue == "r" )
		{
			blue = Math.RandomLong(1, 255);
			bIsRandom = true;
		}

		if( bIsRandom )
			dynamicglow.Tell( "Random Value Detected: mode = " + mode + ", amount = " + amount + ", fx = " + fx + ", red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );


		if( pData.sSteamid == "0" ) // this is a public glow
		{
			glow_off(pPlayer, false);
			amxports.set_user_rendering( id, atoi(fx), atoi(red), atoi(green), atoi(blue), atoi(mode), atoi(amount) );
			g_PlayerGlows[sFixId] = pData.sName;
			dynamicglow.Tell( string(pData.sDescription), pPlayer, HUD_PRINTTALK );
		}
		else
		{
			if( sFixId == pData.sSteamid ) // private glow, authorized user
			{
				glow_off(pPlayer, false);
				amxports.set_user_rendering( id, atoi(fx), atoi(red), atoi(green), atoi(blue), atoi(mode), atoi(amount) );
				g_PlayerGlows[sFixId] = pData.sName;
				dynamicglow.Tell( string(pData.sDescription), pPlayer, HUD_PRINTTALK );
			}
			else // private glow, unauthorized user
				dynamicglow.Tell( "Sorry, glow \"" + glow_name + "\" is private", pPlayer, HUD_PRINTTALK );
		}
	}
	else
        dynamicglow.Tell( "Sorry, glow \"" + glow_name + "\" was not found.", pPlayer, HUD_PRINTTALK );
}

bool is_reloading()
{
	if( g_iTotalGlows == -1)
		return true;

	return false;
}

void set_glow_timed( const int &in id, string glow_name )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;
	string name = pPlayer.pev.netname;

	glow_off(pPlayer, false);

	if( glow_name == "fire" )
	{
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_timed_fire", 1.0f, g_Scheduler.REPEAT_INFINITE_TIMES, id );
		dynamicglow.TellAll( name + " is on fire.", HUD_PRINTTALK );
	}
	else if( glow_name == "police" )
	{
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_timed_police", 1.0f, g_Scheduler.REPEAT_INFINITE_TIMES, id );
		dynamicglow.TellAll( name + " begins glowing red and blue.", HUD_PRINTTALK );
	}
	else if( glow_name == "xmas" )
	{
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_timed_xmas", 1.0f, g_Scheduler.REPEAT_INFINITE_TIMES, id );
		dynamicglow.TellAll( name + " is a christmas tree.", HUD_PRINTTALK );
	}
	else if( glow_name == "rainbow" )
	{
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_timed_rainbow", 2.0f, g_Scheduler.REPEAT_INFINITE_TIMES, id );
		dynamicglow.TellAll( name + " begins changing colors.", HUD_PRINTTALK );
	}
}

void glow_timed_fire( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	if( g_iStrobing[id] == 0 )
	{
		g_iStrobing[id] = 1;
		amxports.set_user_rendering( id, kRenderFxGlowShell, 255, 148, 9, kRenderNormal, 25 );
	}
	else
	{
		g_iStrobing[id] = 0;
		amxports.set_user_rendering( id, kRenderFxGlowShell, 250, 10, 10, kRenderNormal, 25 );
	}
}

void glow_timed_police( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	if( g_iStrobing[id] == 0 )
	{
		g_iStrobing[id] = 1;
		amxports.set_user_rendering( id, kRenderFxGlowShell, 10, 10, 250, kRenderNormal, 25 );
	}
	else
	{
		g_iStrobing[id] = 0;
		amxports.set_user_rendering( id, kRenderFxGlowShell, 250, 10, 10, kRenderNormal, 25 );
	}
}

void glow_timed_xmas( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	if( g_iStrobing[id] == 0 )
	{
		g_iStrobing[id] = 1;
		amxports.set_user_rendering( id, kRenderFxGlowShell, 10, 250, 10, kRenderNormal, 25 );
	}
	else
	{
		g_iStrobing[id] = 0;
		amxports.set_user_rendering( id, kRenderFxGlowShell, 250, 10, 10, kRenderNormal, 25 );
	}
}

void glow_timed_rainbow( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int iRed, iGreen, iBlue;

	iRed = Math.RandomLong(1, 255);
	iGreen = Math.RandomLong(1, 255);
	iBlue = Math.RandomLong(1, 255);

	amxports.set_user_rendering( id, kRenderFxGlowShell, iRed, iGreen, iBlue, kRenderNormal, 25 );
}

void set_glow_random( const int &in id, string message )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	float flTime = 1.0f; // user custom set time value
	string message_old; // work around so you can have glows named random*

	message_old = message; //make sure we retain the original command incase we didn't mean to turn on random
	message.Replace( "random", "" );
	message.Trim();

	if( message.Find("off") != Math.SIZE_MAX )
	{
		if( m_pDynamicGlowThink[id] !is null )
		{
			g_Scheduler.RemoveTimer( m_pDynamicGlowThink[id] );
			@m_pDynamicGlowThink[id] = null;
		}

		amxports.set_user_rendering( id, 0, 0, 0, 0, 0, 100 );
		dynamicglow.Tell( "Random Glowing Off", pPlayer, HUD_PRINTTALK );
	}
	else if( message.Find("basic1") != Math.SIZE_MAX )
	{
		message.Replace( "basic1", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Basic-Pro Random Glowing Enabled! (size= random)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_basic1", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("basic2") != Math.SIZE_MAX )
	{
		message.Replace( "basic2", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Basic Random Glowing Enabled! (size= 1)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_basic2", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("basic3") != Math.SIZE_MAX )
	{
		message.Replace( "basic3", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Basic Random Glowing Enabled! (size= 25)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_basic3", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("basic4") != Math.SIZE_MAX )
	{
		message.Replace( "basic4", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Basic Random Glowing Enabled! (size= 50)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_basic4", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("trans1") != Math.SIZE_MAX )
	{
		message.Replace( "trans1", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Translucent-Pro Random Glowing Enabled! (size= random)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_trans1", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("trans2") != Math.SIZE_MAX )
	{
		message.Replace( "trans2", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Translucent Random Glowing Enabled! (size= 1)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_trans2", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("trans3") != Math.SIZE_MAX )
	{
		message.Replace( "trans3", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Translucent Random Glowing Enabled! (size= 25)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_trans3", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("trans4") != Math.SIZE_MAX )
	{
		message.Replace( "trans4", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Translucent Random Glowing Enabled! (size= 50)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_trans4", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("bright1") != Math.SIZE_MAX )
	{
		message.Replace( "bright1", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Bright-Pro Random Glowing Enabled! (size= random)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_bright1", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("bright2") != Math.SIZE_MAX )
	{
		message.Replace( "bright2", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Bright Random Glowing Enabled! (size= 1)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_bright2", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("bright3") != Math.SIZE_MAX )
	{
		message.Replace( "bright3", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Bright Random Glowing Enabled! (size= 25)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_bright3", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else if( message.Find("bright4") != Math.SIZE_MAX )
	{
		message.Replace( "bright4", "" );
		message.Trim();

		if( message.Length() > 0 ) //check if user passed a time value
		{
			flTime = atof(message); //get time value
			if( flTime < 0.1f ) flTime = 0.1f;
		}

		dynamicglow.Tell( "Bright Random Glowing Enabled! (size= 50)", pPlayer, HUD_PRINTTALK );
		glow_off(pPlayer, false);
		@m_pDynamicGlowThink[id] = g_Scheduler.SetInterval( "glow_random_bright4", flTime, g_Scheduler.REPEAT_INFINITE_TIMES, id );
	}
	else //if not on or off pass command to see if its a valid glow name
	{
		if( !is_reloading() and message_old.Length() > 0 )
			client_glow( pPlayer, message_old );
	}
}

void glow_random_basic1( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int amount = Math.RandomLong(1, 255);
	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 0, amount = " + amount + ", fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 0, amount );
}

void glow_random_basic2( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 0, amount = 1, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 0, 1 );
}

void glow_random_basic3( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 0, amount = 25, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 0, 25 );
}

void glow_random_basic4( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 0, amount = 50, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 0, 50 );
}

void glow_random_trans1( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int amount = Math.RandomLong(1, 255);
	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 2, amount = " + amount + ", fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 2, amount );
}

void glow_random_trans2( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 2, amount = 1, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 2, 1 );
}

void glow_random_trans3( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 2, amount = 25, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 2, 25 );
}

void glow_random_trans4( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 2, amount = 50, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 2, 50 );
}

void glow_random_bright1( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int amount = Math.RandomLong(1, 255);
	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 5, amount = " + amount + ", fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 5, amount );
}

void glow_random_bright2( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);

	//dynamicglow.Tell( "Random Glow: mode = 5, amount = 1, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 5, 1 );
}

void glow_random_bright3( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);
    
	//dynamicglow.Tell( "Random Glow: mode = 5, amount = 25, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 5, 25 );
}

void glow_random_bright4( const int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	if( pPlayer is null ) return;

	int red = Math.RandomLong(1, 255);
	int green = Math.RandomLong(1, 255);
	int blue = Math.RandomLong(1, 255);
    
	//dynamicglow.Tell( "Random Glow: mode = 5, amount = 50, fx = 19, red = " + red + ", green = " + green + ", blue = " + blue, pPlayer, HUD_PRINTTALK );
	amxports.set_user_rendering( id, 19, red, green, blue, 5, 50 );
}

int containi( string sSource, string sString )
{
	uint uiTemp = sSource.ToLowercase().Find(sString.ToLowercase());

	if( uiTemp != Math.SIZE_MAX )
		return int(uiTemp);

	return -1;
}

HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer )
{
	string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));
	if( g_PlayerGlows.exists(sFixId) )
		g_Scheduler.SetTimeout( "DynamicGlowPostSpawn", 1.0f, g_EngineFuncs.IndexOfEdict(pPlayer.edict()) );

	return HOOK_CONTINUE;
}

void DynamicGlowPostSpawn( int &in id )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);
	string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

	GlowData@ pData = cast<GlowData@>(g_GlowColors[string(g_PlayerGlows[sFixId])]);
	set_user_rendering( id, atoi(pData.sFx), atoi(pData.sRed), atoi(pData.sGreen), atoi(pData.sBlue), atoi(pData.sMode), atoi(pData.sAmount) );
}

} //end of namespace DynamicGlow

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		December 31 2017
*	-------------------------
*	- First release
*	-------------------------
*
*	Version: 	1.1
*	Date: 		December 31 2017
*	-------------------------
*	- Added special glows that alternate colors: fire, police, xmas, and rainbow
*	-------------------------
*
*	Version: 	1.2
*	Date: 		January 02 2018
*	-------------------------
*	- Stopped 'glow list' and 'glow display' commands from showing up in chat to prevent spam
*	- Added messages to special glows
*	- Special glows are now turned off when a player disconnects to free up the id-slot
*	-------------------------
*
*	Version: 	1.3
*	Date: 		January 07 2018
*	-------------------------
*	- glow random interval is now capped at 0.1 (lower end)
*	-------------------------
*/
