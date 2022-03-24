#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <SelectiveBhop>
#tryinclude <Discord>

#include <basic>
#include <CJump>
#include <CStreak>
#include <CPlayer>

#define MAX_STREAKS 10
#define VALID_MIN_JUMPS 3
#define VALID_MAX_TICKS 5
#define VALID_MIN_VELOCITY 250
#define PLUGIN_VERSION "1.4.1"

int g_aButtons[MAXPLAYERS + 1];
bool g_bOnGround[MAXPLAYERS + 1];
bool g_bHoldingJump[MAXPLAYERS + 1];
bool g_bInJump[MAXPLAYERS + 1];
bool g_bNoSound = false;

CPlayer g_aPlayers[MAXPLAYERS + 1];
EngineVersion gEV_Type = Engine_Unknown;

ConVar g_cDetectionSound = null;

// Api
Handle g_hOnClientDetected;

char g_sStats[4096];
char g_sBeepSound[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name			= "AntiBhopCheat",
	author			= "BotoX, .Rushaway",
	description		= "Detect all kinds of bhop cheats",
	version			= PLUGIN_VERSION,
	url				= ""
};


public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_cDetectionSound = CreateConVar("sm_antibhopcheat_detection_sound", "1", "Emit a beep sound when someone gets flagged [0 = disabled, 1 = enabled]", 0, true, 0.0, true, 1.0);

	RegAdminCmd("sm_stats", Command_Stats, ADMFLAG_GENERIC, "sm_stats <#userid|name>");
	RegAdminCmd("sm_streak", Command_Streak, ADMFLAG_GENERIC, "sm_streak <#userid|name> [streak]");

	AutoExecConfig(true);

	/* Handle late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientConnected(client))
		{
			if(IsClientInGame(client))
				OnClientPutInServer(client);
		}
	}

	// Api
	g_hOnClientDetected = CreateGlobalForward("AntiBhopCheat_OnClientDetected", ET_Ignore, Param_Cell, Param_String, Param_String);
}

public void OnMapStart()
{
	Handle hConfig = LoadGameConfigFile("funcommands.games");

	if(hConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");

		return;
	}
	
	if(GameConfGetKeyValue(hConfig, "SoundBeep", g_sBeepSound, PLATFORM_MAX_PATH))
	{
		PrecacheSound(g_sBeepSound, true);
	}

	delete hConfig;
}


public void OnClientPutInServer(int client)
{
	g_aPlayers[client] = new CPlayer(client);
}

public void OnClientDisconnect(int client)
{
	if(g_aPlayers[client])
	{
		g_aPlayers[client].Dispose();
		g_aPlayers[client] = null;
	}

	g_bOnGround[client] = false;
	g_bHoldingJump[client] = false;
	g_bInJump[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	g_aButtons[client] = buttons;
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(!IsPlayerAlive(client))
		return;

	CPlayer Player = g_aPlayers[client];

	MoveType ClientMoveType = GetEntityMoveType(client);
	bool bInWater = GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2;

	bool bPrevOnGround = g_bOnGround[client];
	bool bOnGround = !bInWater && GetEntityFlags(client) & FL_ONGROUND;

	bool bPrevHoldingJump = g_bHoldingJump[client];
	bool bHoldingJump = view_as<bool>(g_aButtons[client] & IN_JUMP);

	bool bInJump = g_bInJump[client];

	float fVecVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVecVelocity);
	fVecVelocity[2] = 0.0;
	float fVelocity = GetVectorLength(fVecVelocity);

	if(bInJump && (bInWater || ClientMoveType == MOVETYPE_LADDER || ClientMoveType == MOVETYPE_NOCLIP))
		bOnGround = true;

	if(bOnGround)
	{
		if(!bPrevOnGround)
		{
			g_bOnGround[client] = true;
			g_bInJump[client] = false;
			if(bInJump)
				OnTouchGround(Player, tickcount, fVelocity);
		}
	}
	else
	{
		if(bPrevOnGround)
			g_bOnGround[client] = false;
	}

	if(bHoldingJump)
	{
		if(!bPrevHoldingJump && !bOnGround && (bPrevOnGround || bInJump))
		{
			g_bHoldingJump[client] = true;
			g_bInJump[client] = true;
			OnPressJump(Player, tickcount, fVelocity, bPrevOnGround);
		}
	}
	else
	{
		if(bPrevHoldingJump)
		{
			g_bHoldingJump[client] = false;
			OnReleaseJump(Player, tickcount, fVelocity);
		}
	}
}

// TODO: Release after touch ground

void OnTouchGround(CPlayer Player, int iTick, float fVelocity)
{
	//PrintToServer("%d - OnTouchGround", iTick);

	CStreak CurStreak = Player.hStreak;
	ArrayList hJumps = CurStreak.hJumps;
	CJump hJump = hJumps.Get(hJumps.Length - 1);

	hJump.iEndTick = iTick;
	hJump.fEndVel = fVelocity;

	int iLength = hJumps.Length;
	if(iLength == VALID_MIN_JUMPS)
	{
		CurStreak.bValid = true;

		// Current streak is valid, push onto hStreaks ArrayList
		ArrayList hStreaks = Player.hStreaks;
		if(hStreaks.Length == MAX_STREAKS)
		{
			// Keep the last 10 streaks
			CStreak hStreak = hStreaks.Get(0);
			hStreak.Dispose();
			hStreaks.Erase(0);
		}
		hStreaks.Push(CurStreak);

		for(int i = 0; i < iLength - 1; i++)
		{
			CJump hJump_ = hJumps.Get(i);
			DoStats(Player, CurStreak, hJump_);
		}
	}
	else if(iLength > VALID_MIN_JUMPS)
	{
		CJump hJump_ = hJumps.Get(hJumps.Length - 2);
		DoStats(Player, CurStreak, hJump_);
	}
}

void OnPressJump(CPlayer Player, int iTick, float fVelocity, bool bLeaveGround)
{
	//PrintToServer("%d - OnPressJump %d", iTick, bLeaveGround);

	CStreak CurStreak = Player.hStreak;
	ArrayList hJumps = CurStreak.hJumps;
	CJump hJump;

	if(bLeaveGround)
	{
		int iPrevJump = -1;
		// Check if we should start a new streak
		if(hJumps.Length)
		{
			// Last jump was more than VALID_MAX_TICKS ticks ago or not valid and fVelocity < VALID_MIN_VELOCITY
			hJump = hJumps.Get(hJumps.Length - 1);
			if(hJump.iEndTick < iTick - VALID_MAX_TICKS || fVelocity < VALID_MIN_VELOCITY)
			{
				if(CurStreak.bValid)
				{
					CurStreak.iEndTick = iTick;

					DoStats(Player, CurStreak, hJump);
				}
				else
					CurStreak.Dispose();

				CurStreak = new CStreak();
				Player.hStreak = CurStreak;
				hJumps = CurStreak.hJumps;
			}
			else
			{
				iPrevJump = iTick - hJump.iEndTick;
				hJump.iNextJump = iPrevJump;
			}
		}

		hJump = new CJump();
		hJump.iStartTick = iTick;
		hJump.fStartVel = fVelocity;
		if(iPrevJump != -1)
			hJump.iPrevJump = iPrevJump;
		hJumps.Push(hJump);
	}
	else
		hJump = hJumps.Get(hJumps.Length - 1);

	ArrayList hPresses = hJump.hPresses;
	hPresses.Push(iTick);
}

void OnReleaseJump(CPlayer Player, int iTick, float fVelocity)
{
	//PrintToServer("%d - OnReleaseJump", iTick);

	CStreak CurStreak = Player.hStreak;
	ArrayList hJumps = CurStreak.hJumps;
	CJump hJump = hJumps.Get(hJumps.Length - 1);
	ArrayList hPresses = hJump.hPresses;

	hPresses.Set(hPresses.Length - 1, iTick, 1);
}

void DoStats(CPlayer Player, CStreak CurStreak, CJump hJump)
{
	int client = Player.iClient;
	int aJumps[3] = {0, 0, 0};
	int iPresses = 0;
	int iTicks = 0;
	int iLastJunk = 0;

	CurStreak.iJumps++;
	Player.iJumps++;

	ArrayList hPresses = hJump.hPresses;
	int iStartTick = hJump.iStartTick;
	int iEndTick = hJump.iEndTick;
	int iPrevJump = hJump.iPrevJump;
	int iNextJump = hJump.iNextJump;

	if(iPrevJump > 0)
	{
		int iPerf = iPrevJump - 1;
		if(iPerf > 2)
			iPerf = 2;

		aJumps[iPerf]++;
	}

	iPresses = hPresses.Length;
	iTicks = iEndTick - iStartTick;
	iLastJunk = iEndTick - hPresses.Get(iPresses - 1, 1);

	float PressesPerTick = (iPresses * 4.0) / float(iTicks);
	if(PressesPerTick >= 0.85)
	{
		CurStreak.iHyperJumps++;
		Player.iHyperJumps++;
	}

	if(iNextJump != -1 && iNextJump <= 1 && (iLastJunk > 5 || iPresses <= 2) && hJump.fEndVel >= 285.0)
	{
		CurStreak.iHackJumps++;
		Player.iHackJumps++;
	}

	int aGlobalJumps[3];
	Player.GetJumps(aGlobalJumps);
	aGlobalJumps[0] += aJumps[0];
	aGlobalJumps[1] += aJumps[1];
	aGlobalJumps[2] += aJumps[2];
	Player.SetJumps(aGlobalJumps);

	int aStreakJumps[3];
	CurStreak.GetJumps(aStreakJumps);
	aStreakJumps[0] += aJumps[0];
	aStreakJumps[1] += aJumps[1];
	aStreakJumps[2] += aJumps[2];
	CurStreak.SetJumps(aStreakJumps);

	int iStreakJumps = CurStreak.iJumps;
	if(iStreakJumps >= 6)
	{
		float HackRatio = CurStreak.iHackJumps / float(iStreakJumps);
		if(HackRatio >= 0.85 && !Player.bFlagged)
		{
			Player.bFlagged = true;
			NotifyAdmins(client, "bhop hack streak");
//			KickClient(client, "Turn off your hack!");
			return;
		}

		float HyperRatio = CurStreak.iHyperJumps / float(iStreakJumps);
		if(HyperRatio >= 0.85 && !Player.bFlagged)
		{
			Player.bFlagged = true;
			NotifyAdmins(client, "hyperscroll streak");
			CPrintToChat(client, "{green}[SM]{default} Turn off your bhop macro/script or hyperscroll!");
			CPrintToChat(client, "{green}[SM]{default} Your bhop has been {red}turned off{default} until the end of the map.");
			LimitBhop(client, true);
			return;
		}
	}

	int iGlobalJumps = Player.iJumps;
	if(iGlobalJumps >= 25)
	{
		float HackRatio = Player.iHackJumps / float(iGlobalJumps);
		if(HackRatio >= 0.65 && !Player.bFlagged)
		{
			Player.bFlagged = true;
			NotifyAdmins(client, "bhop hack global");
//			KickClient(client, "Turn off your hack!");
			return;
		}

		float HyperRatio = Player.iHyperJumps / float(iGlobalJumps);
		if(HyperRatio >= 0.50 && !Player.bFlagged)
		{
			Player.bFlagged = true;
			NotifyAdmins(client, "hyperscroll global");
			CPrintToChat(client, "{green}[SM]{default} Turn off your bhop macro/script or hyperscroll!");
			CPrintToChat(client, "{green}[SM]{default} Your bhop has been {red}turned off{default} until the end of the map.");
			LimitBhop(client, true);
			return;
		}
	}
}

void NotifyAdmins(int client, const char[] sReason)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && CheckCommandAccess(i, "sm_stats", ADMFLAG_GENERIC))
		{
			CPrintToChat(i, "{green}[SM]{red} %L {default}has been detected for {red}%s{default}", client, sReason);
			CPrintToChat(i, "{green}[SM]{red} Please check your console if it's not a false flag!", client);
			PrintStats(i, client);
			PrintStreak(i, client, -1, true);

			if(!g_bNoSound && g_cDetectionSound.BoolValue)
			{
				if(gEV_Type == Engine_CSS || gEV_Type == Engine_TF2)
				{
					EmitSoundToClient(i, g_sBeepSound);
				}
				else
				{
					ClientCommand(i, "play */%s", g_sBeepSound);
				}
			}
		}
	}

	Forward_OnDetected(client, sReason, g_sStats);
	g_bNoSound = false;
}

public Action Command_Stats(int client, int argc)
{
	if(argc < 1 || argc > 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_stats <#userid|name>");
		return Plugin_Handled;
	}

	char sArg[65];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArg, sizeof(sArg));

	if((iTargetCount = ProcessTargetString(sArg, client, iTargets, MAXPLAYERS, COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		PrintStats(client, iTargets[i]);
	}

	return Plugin_Handled;
}

void PrintStats(int client, int iTarget)
{
	PrintToConsole(client, "[SM] Bunnyhop stats for %L", iTarget);

	CPlayer Player = g_aPlayers[iTarget];
	ArrayList hStreaks = Player.hStreaks;
	CStreak hStreak = Player.hStreak;
	int iStreaks = hStreaks.Length;

	// Try showing latest valid streak
	if(!hStreak.bValid)
	{
		if(iStreaks)
			hStreak = hStreaks.Get(iStreaks - 1);
	}

	int iGlobalJumps = Player.iJumps;
	float HyperRatio = Player.iHyperJumps / float(iGlobalJumps);
	float HackRatio = Player.iHackJumps / float(iGlobalJumps);

	PrintToConsole(client, "Global jumps: %d | Hyper?: %.1f%% | Hack?: %.1f%%",
		iGlobalJumps, HyperRatio * 100.0, HackRatio * 100.0);


	int aGlobalJumps[3];
	Player.GetJumps(aGlobalJumps);

	PrintToConsole(client, "Global jumps perf group (1 2 +): %1.f%%  %1.f%%  %1.f%%",
		(aGlobalJumps[0] / float(iGlobalJumps)) * 100.0,
		(aGlobalJumps[1] / float(iGlobalJumps)) * 100.0,
		(aGlobalJumps[2] / float(iGlobalJumps)) * 100.0);


	PrintToConsole(client, "more to come...");
}

public Action Command_Streak(int client, int argc)
{
	if(argc < 1 || argc > 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_streak <#userid|name> [streak]");
		return Plugin_Handled;
	}

	char sArg[65];
	char sArg2[8];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;
	int iStreak = -1;

	GetCmdArg(1, sArg, sizeof(sArg));

	if(argc == 2)
	{
		GetCmdArg(2, sArg2, sizeof(sArg2));
		iStreak = StringToInt(sArg2);
	}

	if((iTargetCount = ProcessTargetString(sArg, client, iTargets, MAXPLAYERS, COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		PrintStreak(client, iTargets[i], iStreak);
	}

	return Plugin_Handled;
}

void PrintStreak(int client, int iTarget, int iStreak, bool bDetected=false)
{
	g_sStats = "";

	PrintToConsole(client, "[SM] Bunnyhop streak %d for %L", iStreak, iTarget);

	if (bDetected)
		Format(g_sStats, sizeof(g_sStats), "%sBunnyhop streak %d for %L\n",
		g_sStats, iStreak, iTarget);

	CPlayer Player = g_aPlayers[iTarget];
	ArrayList hStreaks = Player.hStreaks;
	CStreak hStreak = Player.hStreak;
	int iStreaks = hStreaks.Length;

	// Try showing latest valid streak
	if(iStreak <= 0 && !hStreak.bValid)
	{
		if(iStreaks)
			hStreak = hStreaks.Get(iStreaks - 1);
	}
	else if(iStreak > 0)
	{
		if(iStreak > MAX_STREAKS)
		{
			CReplyToCommand(client, "{green}[SM] {default}Streak is out of bounds (max. %d)!", MAX_STREAKS);
			return;
		}

		int iIndex = iStreaks - iStreak;
		if(iIndex < 0)
		{
			CReplyToCommand(client, "{green}[SM] {default}Only {olive}%d {default}streaks are available for this player right now!", iStreaks);
			return;
		}

		hStreak = hStreaks.Get(iIndex);
	}

	int iStreakJumps = hStreak.iJumps;
	float HyperRatio = hStreak.iHyperJumps / float(iStreakJumps);
	float HackRatio = hStreak.iHackJumps / float(iStreakJumps);

	PrintToConsole(client, "Streak jumps: %d | Hyper?: %.1f%% | Hack?: %.1f%%",
		iStreakJumps, HyperRatio * 100.0, HackRatio * 100.0);

	if (bDetected)
		Format(g_sStats, sizeof(g_sStats), "%sStreak jumps: %d | Hyper?: %.1f%% | Hack?: %.1f%%\n",
		g_sStats, iStreakJumps, HyperRatio * 100.0, HackRatio * 100.0);

	int aStreakJumps[3];
	hStreak.GetJumps(aStreakJumps);

	PrintToConsole(client, "Streak jumps perf group (1 2 +): %1.f%%  %1.f%%  %1.f%%",
		(aStreakJumps[0] / float(iStreakJumps)) * 100.0,
		(aStreakJumps[1] / float(iStreakJumps)) * 100.0,
		(aStreakJumps[2] / float(iStreakJumps)) * 100.0);

	if (bDetected)
		Format(g_sStats, sizeof(g_sStats), "%sStreak jumps perf group (1 2 +): %1.f%%  %1.f%%  %1.f%%\n",
		g_sStats,
		(aStreakJumps[0] / float(iStreakJumps)) * 100.0,
		(aStreakJumps[1] / float(iStreakJumps)) * 100.0,
		(aStreakJumps[2] / float(iStreakJumps)) * 100.0);

	PrintToConsole(client, "#%2s %5s %7s %7s %5s %5s %8s %4s %6s   %s",
		"id", " diff", "  invel", " outvel", " gain", " comb", " avgdist", " num", " avg+-", "pattern");

	if (bDetected)
		Format(g_sStats, sizeof(g_sStats), "%s#%2s %5s %7s %7s %5s %5s %8s %4s %6s   %s\n",
		g_sStats, "id", " diff", "  invel", " outvel", " gain", " comb", " avgdist", " num", " avg+-", "pattern");

	ArrayList hJumps = hStreak.hJumps;
	float fPrevVel = 0.0;
	int iPrevEndTick = -1;

	for(int i = 0; i < hJumps.Length; i++)
	{
		CJump hJump = hJumps.Get(i);
		ArrayList hPresses = hJump.hPresses;

		float fInVel = hJump.fStartVel;
		float fOutVel = hJump.fEndVel;
		int iEndTick = hJump.iEndTick;

		static char sPattern[1024];
		int iPatternLen = 0;
		int iPrevTick = -1;
		int iTicks;

		if(iPrevEndTick != -1)
		{
			iTicks = hJump.iStartTick - iPrevEndTick;
			for(int k = 0; k < iTicks && k < 16; k++)
				sPattern[iPatternLen++] = '|';
		}

		float fAvgDist = 0.0;
		float fAvgDownUp = 0.0;

		int iPresses = hPresses.Length;
		for(int j = 0; j < iPresses; j++)
		{
			int aJunkJump[2];
			hPresses.GetArray(j, aJunkJump);

			if(iPrevTick != -1)
			{
				iTicks = aJunkJump[0] - iPrevTick;
				for(int k = 0; k < iTicks && k < 16; k++)
					sPattern[iPatternLen++] = '.';

				fAvgDist += iTicks;
			}

			sPattern[iPatternLen++] = '^';

			iTicks = aJunkJump[1] - aJunkJump[0];
			for(int k = 0; k < iTicks && k < 16; k++)
				sPattern[iPatternLen++] = ',';

			fAvgDownUp += iTicks;

			sPattern[iPatternLen++] = 'v';

			iPrevTick = aJunkJump[1];
		}

		fAvgDist /= iPresses;
		fAvgDownUp /= iPresses;

		iTicks = iEndTick - iPrevTick;
		for(int k = 0; k < iTicks && k < 16; k++)
			sPattern[iPatternLen++] = '.';

		sPattern[iPatternLen++] = '|';
		sPattern[iPatternLen++] = '\0';

		if(fPrevVel == 0.0)
			fPrevVel = fInVel;

		PrintToConsole(client, "#%2d %4d%% %7.1f %7.1f %4d%% %4d%% %8.2f %4d %6.2f   %s",
			i,
			fPrevVel == 0.0 ? 100 : RoundFloat((fInVel / fPrevVel) * 100.0 - 100.0),
			fInVel,
			fOutVel,
			fInVel == 0.0 ? 100 : RoundFloat((fOutVel / fInVel) * 100.0 - 100.0),
			fPrevVel == 0.0 ? 100 : RoundFloat((fOutVel / fPrevVel) * 100.0 - 100.0),
			fAvgDist,
			iPresses,
			fAvgDownUp,
			sPattern);

		if (bDetected)
			Format(g_sStats, sizeof(g_sStats), "%s#%2d %4d%% %7.1f %7.1f %4d%% %4d%% %8.2f %4d %6.2f   %s\n",
			g_sStats,
			i,
			fPrevVel == 0.0 ? 100 : RoundFloat((fInVel / fPrevVel) * 100.0 - 100.0),
			fInVel,
			fOutVel,
			fInVel == 0.0 ? 100 : RoundFloat((fOutVel / fInVel) * 100.0 - 100.0),
			fPrevVel == 0.0 ? 100 : RoundFloat((fOutVel / fPrevVel) * 100.0 - 100.0),
			fAvgDist,
			iPresses,
			fAvgDownUp,
			sPattern);

		iPrevEndTick = iEndTick;
		fPrevVel = fOutVel;
	}
}

void Discord_Notify(int client, const char[] reason, const char[] stats)
{
	char sWebhook[64];
	Format(sWebhook, sizeof(sWebhook), "antibhopcheat");

	char message[4096];
	Format(message, sizeof(message), "%L has been detected for **%s**.```%s```", client, reason, stats);

	char sMessage[4096];
	char sTime[64];
	int iTime = GetTime();
	FormatTime(sTime, sizeof(sTime), "%m/%d/%Y @ %H:%M:%S", iTime);

	char currentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(currentMap, sizeof(currentMap));

	Format(sMessage, sizeof(sMessage), "```(v:%s) %s on %s``` %s", PLUGIN_VERSION, sTime, currentMap, message);
	ReplaceString(sMessage, sizeof(sMessage), "\n", "\\n", false);

	Discord_SendMessage(sWebhook, sMessage);
}

bool Forward_OnDetected(int client, const char[] reason, const char[] stats)
{
	Call_StartForward(g_hOnClientDetected);
	Call_PushCell(client);
	Call_PushString(reason);
	Call_PushString(stats);
	Call_Finish();

#if defined _Discord_Included
	Discord_Notify(client, reason, stats);
#endif

	g_sStats = "";
}
