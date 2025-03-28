#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <basic>
#include <CJump>
#include <CStreak>
#include <CPlayer>

#undef REQUIRE_PLUGIN
#tryinclude <SelectiveBhop>
#define REQUIRE_PLUGIN

#define MAX_STREAKS 10
#define VALID_MIN_JUMPS 3
#define VALID_MAX_TICKS 5
#define VALID_MIN_VELOCITY 250

#define STREAK_HACK "bhop hack streak"
#define STREAK_HYPER "hyperscroll streak"
#define GLOBAL_HACK "global bhop hack"
#define GLOBAL_HYPER "global hyperscroll"

CPlayer g_aPlayers[MAXPLAYERS + 1] = { null, ... };
EngineVersion gEV_Type = Engine_Unknown;

ConVar g_cvSvGravity, g_cvSvAutoBhop, g_cDetectionSound = null, g_cvMaxDetections;
ConVar g_cvCurrentJumps, g_cvCurrentHyper, g_cvCurrentHack, g_cvCurrentHackKick;
ConVar g_cvGlobalJumps, g_cvGlobalHyper, g_cvGlobalHack, g_cvGlobalHackKick;
#if defined _SelectiveBhop_Included
ConVar g_cvCurrentStreakLimitBhop, g_cvGlobalStreakLimitBhop, g_cvCurrentHackLimitBhop, g_cvGlobalHackLimitBhop;
#endif

char g_sStats[1993], g_sBeepSound[PLATFORM_MAX_PATH];

float g_fCurrentHyper
	, g_fCurrentHack
	, g_fGlobalHyper
	, g_fGlobalHack;

bool g_bOnGround[MAXPLAYERS + 1]
	, g_bHoldingJump[MAXPLAYERS + 1]
	, g_bInJump[MAXPLAYERS + 1]
	, g_bFlagged[MAXPLAYERS + 1] = { false, ... }
	, g_bCurrentHackKick
	, g_bGlobalHackKick
	, g_bCurrentStreakHyperLimited
	, g_bCurrentHackHyperLimited
	, g_bGlobalStreakHyperLimited
	, g_bGlobalHackHyperLimited
	, g_bLate = false
	, g_bNoSound = false
#if defined _SelectiveBhop_Included
	, g_Plugin_SelectiveBhop = false
#endif
	, g_bSvAutoBhop;

int g_iCurrentJumps,
	g_iGlobalJumps,
	g_iMaxFlags,
	g_iSvGravity = 800,
	g_iButtons[MAXPLAYERS + 1],
	g_iFlagged[MAXPLAYERS + 1];

Handle g_hOnClientDetected;

public Plugin myinfo =
{
	name			= "AntiBhopCheat",
	author			= "BotoX, .Rushaway",
	description		= "Detect all kinds of bhop cheats",
	version			= "1.8.1",
	url				= ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	RegPluginLibrary("AntiBhopCheat");
	g_hOnClientDetected = CreateGlobalForward("AntiBhopCheat_OnClientDetected", ET_Ignore, Param_Cell, Param_String, Param_String);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_cvSvGravity = FindConVar("sv_gravity");
	g_cvSvAutoBhop = FindConVar("sv_autobunnyhopping");
	g_cDetectionSound = CreateConVar("sm_antibhopcheat_detection_sound", "1", "Emit a beep sound when someone gets flagged [0 = disabled, 1 = enabled]", 0, true, 0.0, true, 1.0);
	g_cvMaxDetections = CreateConVar("sm_antibhopcheat_max_detection", "2", "When player reach this value start apply punishements.", FCVAR_PROTECTED);

	/* Current Streak */
	g_cvCurrentJumps = CreateConVar("sm_antibhopcheat_current_jumps", "6", "Current Streak: Numbers of jumps to reach to analyze the streak", FCVAR_PROTECTED, true, 1.0);
	g_cvCurrentHyper = CreateConVar("sm_antibhopcheat_current_hyper", "0.95", "Current Streak: Threshold percentage required to detect Hyperscroll. Set to < 0.0 to disable detection", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_cvCurrentHack = CreateConVar("sm_antibhopcheat_current_hack", "0.90", "Current Streak: Threshold percentage for detecting Hacks. Set to < 0.0 to disable detection", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_cvCurrentHackKick = CreateConVar("sm_antibhopcheat_current_hack_kick", "0", "Current Streak: Kick if a player is flagged for HACK? [0 = disabled, 1 = enabled]", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	/* Global Streak */
	g_cvGlobalJumps = CreateConVar("sm_antibhopcheat_global_jumps", "30", "Global Streak: Numbers of jumps to reach to analyze all player streaks", FCVAR_PROTECTED, true, 20.0);
	g_cvGlobalHyper = CreateConVar("sm_antibhopcheat_global_hyper", "0.80", "Global Streak: Threshold percentage required to detect Hyperscroll. Set to < 0.0 to disable detection", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_cvGlobalHack = CreateConVar("sm_antibhopcheat_global_hack", "0.75", "Global Streak: Threshold percentage for detecting Hacks. Set to < 0.0 to disable detection", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	g_cvGlobalHackKick = CreateConVar("sm_antibhopcheat_global_hack_kick", "0", "Global Streak: Kick if a player is flagged for HACK? [0 = disabled, 1 = enabled]", FCVAR_NOTIFY, true, 0.0, true, 1.0);

#if defined _SelectiveBhop_Included
	/* Limit Bhop */
	g_cvCurrentStreakLimitBhop = CreateConVar("sm_antibhopcheat_current_streak_limitbhop", "1", "Current Streak: Limit bhop if a player is flagged for Hyperscroll [0 = disabled, 1 = enabled]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvCurrentHackLimitBhop = CreateConVar("sm_antibhopcheat_current_hack_limitbhop", "1", "Current Streak: Limit bhop if a player is flagged for Hack [0 = disabled, 1 = enabled]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvGlobalStreakLimitBhop = CreateConVar("sm_antibhopcheat_global_streak_limitbhop", "1", "Global Streak: Limit bhop if a player is flagged for Hyperscroll [0 = disabled, 1 = enabled]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvGlobalHackLimitBhop = CreateConVar("sm_antibhopcheat_global_hack_limitbhop", "1", "Global Streak: Limit bhop if a player is flagged for Hack [0 = disabled, 1 = enabled]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
#endif
	RegAdminCmd("sm_stats", Command_Stats, ADMFLAG_GENERIC, "sm_stats <#userid|name>");
	RegAdminCmd("sm_streak", Command_Streak, ADMFLAG_GENERIC, "sm_streak <#userid|name> [streak]");

	AutoExecConfig(true);
	OnConfigsExecuted();

	HookConVarChange(g_cvSvGravity, OnConVarChanged);
	if (g_cvSvAutoBhop != null)
		HookConVarChange(g_cvSvAutoBhop, OnConVarChanged);
	HookConVarChange(g_cDetectionSound, OnConVarChanged);
	HookConVarChange(g_cvMaxDetections, OnConVarChanged);
	HookConVarChange(g_cvCurrentJumps, OnConVarChanged);
	HookConVarChange(g_cvCurrentHyper, OnConVarChanged);
	HookConVarChange(g_cvCurrentHack, OnConVarChanged);
	HookConVarChange(g_cvCurrentHackKick, OnConVarChanged);
	HookConVarChange(g_cvGlobalJumps, OnConVarChanged);
	HookConVarChange(g_cvGlobalHyper, OnConVarChanged);
	HookConVarChange(g_cvGlobalHack, OnConVarChanged);
	HookConVarChange(g_cvGlobalHackKick, OnConVarChanged);
#if defined _SelectiveBhop_Included
	HookConVarChange(g_cvCurrentStreakLimitBhop, OnConVarChanged);
	HookConVarChange(g_cvCurrentHackLimitBhop, OnConVarChanged);
	HookConVarChange(g_cvGlobalStreakLimitBhop, OnConVarChanged);
	HookConVarChange(g_cvGlobalHackLimitBhop, OnConVarChanged);
#endif

	if (g_bLate)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientConnected(client))
			{
				if (IsClientInGame(client))
					ResetPlayerData(client);
			}
		}
	}
}

#if defined _SelectiveBhop_Included
public void OnAllPluginsLoaded()
{
	g_Plugin_SelectiveBhop = LibraryExists("SelectiveBhop");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "SelectiveBhop", false) == 0)
		g_Plugin_SelectiveBhop = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "SelectiveBhop", false) == 0)
		g_Plugin_SelectiveBhop = false;
}
#endif

public void OnConfigsExecuted()
{
	g_iSvGravity = GetConVarInt(g_cvSvGravity);
	if (g_cvSvAutoBhop != null)
		g_bSvAutoBhop = GetConVarBool(g_cvSvAutoBhop);
	else
		g_bSvAutoBhop = false;
	g_bNoSound = GetConVarBool(g_cDetectionSound);
	g_iMaxFlags = GetConVarInt(g_cvMaxDetections);
	g_iCurrentJumps = GetConVarInt(g_cvCurrentJumps);
	g_fCurrentHyper = GetConVarFloat(g_cvCurrentHyper);
	g_fCurrentHack = GetConVarFloat(g_cvCurrentHack);
	g_bCurrentHackKick = GetConVarBool(g_cvCurrentHackKick);
	g_iGlobalJumps = GetConVarInt(g_cvGlobalJumps);
	g_fGlobalHyper = GetConVarFloat(g_cvGlobalHyper);
	g_fGlobalHack = GetConVarFloat(g_cvGlobalHack);
	g_bGlobalHackKick = GetConVarBool(g_cvGlobalHackKick);
#if defined _SelectiveBhop_Included
	g_bCurrentStreakHyperLimited = GetConVarBool(g_cvCurrentStreakLimitBhop);
	g_bCurrentHackHyperLimited = GetConVarBool(g_cvCurrentHackLimitBhop);
	g_bGlobalStreakHyperLimited = GetConVarBool(g_cvGlobalStreakLimitBhop);
	g_bGlobalHackHyperLimited = GetConVarBool(g_cvGlobalHackLimitBhop);
#endif
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvSvGravity)
		g_iSvGravity = GetConVarInt(convar);
	else if (convar == g_cvSvAutoBhop && g_cvSvAutoBhop != null)
		g_bSvAutoBhop = GetConVarBool(convar);
	else if (convar == g_cDetectionSound)
		g_bNoSound = GetConVarBool(convar);
	else if (convar == g_cvMaxDetections)
		g_iMaxFlags = GetConVarInt(convar);
	else if (convar == g_cvCurrentJumps)
		g_iCurrentJumps = GetConVarInt(convar);
	else if (convar == g_cvCurrentHyper)
		g_fCurrentHyper = GetConVarFloat(convar);
	else if (convar == g_cvCurrentHack)
		g_fCurrentHack = GetConVarFloat(convar);
	else if (convar == g_cvCurrentHackKick)
		g_bCurrentHackKick = GetConVarBool(convar);
	else if (convar == g_cvGlobalJumps)
		g_iGlobalJumps = GetConVarInt(convar);
	else if (convar == g_cvGlobalHyper)
		g_fGlobalHyper = GetConVarFloat(convar);
	else if (convar == g_cvGlobalHack)
		g_fGlobalHack = GetConVarFloat(convar);
	else if (convar == g_cvGlobalHackKick)
		g_bGlobalHackKick = GetConVarBool(convar);
#if defined _SelectiveBhop_Included
	else if (convar == g_cvCurrentStreakLimitBhop)
		g_bCurrentStreakHyperLimited = GetConVarBool(convar);
	else if (convar == g_cvCurrentHackLimitBhop)
		g_bCurrentHackHyperLimited = GetConVarBool(convar);
	else if (convar == g_cvGlobalStreakLimitBhop)
		g_bGlobalStreakHyperLimited = GetConVarBool(convar);
	else if (convar == g_cvGlobalHackLimitBhop)
		g_bGlobalHackHyperLimited = GetConVarBool(convar);
#endif
}

public void OnMapStart()
{
	Handle hConfig = LoadGameConfigFile("funcommands.games");

	if (hConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	if (GameConfGetKeyValue(hConfig, "SoundBeep", g_sBeepSound, PLATFORM_MAX_PATH))
		PrecacheSound(g_sBeepSound, true);

	delete hConfig;
}

public void OnClientConnected(int client)
{
	InitPlayerData(client);
}

public void OnClientDisconnect(int client)
{
	DeletePlayerData(client);
	ResetValues(client);
	g_iFlagged[client] = 0;
	g_bFlagged[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (g_bSvAutoBhop || !IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) || IsClientSourceTV(client))
		return Plugin_Continue;

	g_iButtons[client] = buttons;
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (g_bSvAutoBhop || g_iSvGravity != 800 || !IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) || IsClientSourceTV(client))
		return;

	float fVecVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVecVelocity);
	fVecVelocity[2] = 0.0;
	float fVelocity = GetVectorLength(fVecVelocity);

	// With this velocity in 99% the player will be flagged (and can create false positives)
	if (fVelocity > 700.0)
		return;

	MoveType ClientMoveType = GetEntityMoveType(client);
	CPlayer Player = g_aPlayers[client];

	bool bPrevOnGround = g_bOnGround[client];
	bool bInWater = GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2;
	bool bOnGround = !bInWater && GetEntityFlags(client) & FL_ONGROUND;
	bool bPrevHoldingJump = g_bHoldingJump[client];
	bool bHoldingJump = view_as<bool>(g_iButtons[client] & IN_JUMP);
	bool bInJump = g_bInJump[client];

	if (bInJump && (bInWater || ClientMoveType == MOVETYPE_LADDER || ClientMoveType == MOVETYPE_NOCLIP) && GetEntityGravity(client) == 0.0)
		bOnGround = true;

	// Debug with PrinToChatAll
	// PrintToChatAll("bInJump = %s", bInJump ? "true" : "false");
	// PrintToChatAll("ClientMoveType = %d", ClientMoveType);
	// PrintToChatAll("GetEntityGravity(client) = %f", GetEntityGravity(client));
	// PrintToChatAll("g_iSvGravity = %d", g_iSvGravity);
	// PrintToChatAll("bInWater = %d", bInWater);

	if (bOnGround)
	{
		if (!bPrevOnGround)
		{
			g_bOnGround[client] = true;
			g_bInJump[client] = false;
			if (bInJump)
				OnTouchGround(Player, tickcount, fVelocity);
		}
	}
	else
	{
		if (bPrevOnGround)
			g_bOnGround[client] = false;
	}

	if (bHoldingJump)
	{
		if (!bPrevHoldingJump && !bOnGround && (bPrevOnGround || bInJump))
		{
			g_bHoldingJump[client] = true;
			g_bInJump[client] = true;
			OnPressJump(Player, tickcount, fVelocity, bPrevOnGround);
		}
	}
	else
	{
		if (bPrevHoldingJump)
		{
			g_bHoldingJump[client] = false;
			OnReleaseJump(Player, tickcount, fVelocity);
		}
	}
}

// TODO: Release after touch ground

void OnTouchGround(CPlayer Player, int iTick, float fVelocity)
{
	//PrintToChatAll("%d : %f - OnTouchGround", iTick, fVelocity);

	CStreak CurStreak = Player.hStreak;
	ArrayList hJumps = CurStreak.hJumps;
	CJump hJump = hJumps.Get(hJumps.Length - 1);

	hJump.iEndTick = iTick;
	hJump.fEndVel = fVelocity;

	int iLength = hJumps.Length;
	if (iLength == VALID_MIN_JUMPS)
	{
		CurStreak.bValid = true;

		// Current streak is valid, push onto hStreaks ArrayList
		ArrayList hStreaks = Player.hStreaks;
		if (hStreaks.Length == MAX_STREAKS)
		{
			// Keep the last 10 streaks
			CStreak hStreak = hStreaks.Get(0);
			hStreak.Dispose();
			hStreaks.Erase(0);
		}
		hStreaks.Push(CurStreak);

		for (int i = 0; i < iLength - 1; i++)
		{
			CJump hJump_ = hJumps.Get(i);
			DoStats(Player, CurStreak, hJump_);
		}
	}
	else if (iLength > VALID_MIN_JUMPS)
	{
		CJump hJump_ = hJumps.Get(hJumps.Length - 2);
		DoStats(Player, CurStreak, hJump_);
	}
}

void OnPressJump(CPlayer Player, int iTick, float fVelocity, bool bLeaveGround)
{
	//PrintToChatAll("%d : %f - OnPressJump %d", iTick, fVelocity, bLeaveGround);

	CStreak CurStreak = Player.hStreak;
	ArrayList hJumps = CurStreak.hJumps;
	CJump hJump;

	if (bLeaveGround)
	{
		int iPrevJump = -1;
		// Check if we should start a new streak
		if (hJumps.Length)
		{
			// Last jump was more than VALID_MAX_TICKS ticks ago or not valid and fVelocity < VALID_MIN_VELOCITY
			hJump = hJumps.Get(hJumps.Length - 1);
			if (hJump.iEndTick < iTick - VALID_MAX_TICKS || fVelocity < VALID_MIN_VELOCITY)
			{
				if ( CurStreak.bValid)
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
		if (iPrevJump != -1)
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
	//PrintToChatAll("%d : %f - OnReleaseJump", iTick, fVelocity);

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

	if (iPrevJump > 0)
	{
		int iPerf = iPrevJump - 1;
		if (iPerf > 2)
			iPerf = 2;

		aJumps[iPerf]++;
	}

	iPresses = hPresses.Length;
	iTicks = iEndTick - iStartTick;
	iLastJunk = iEndTick - hPresses.Get(iPresses - 1, 1);

	float PressesPerTick = (iPresses * 4.0) / float(iTicks);
	if (PressesPerTick >= 0.85)
	{
		CurStreak.iHyperJumps++;
		Player.iHyperJumps++;
	}

	if (iNextJump != -1 && iNextJump <= 1 && (iLastJunk > 5 || iPresses <= 2) && hJump.fEndVel >= 285.0)
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
	int iGlobalJumps = Player.iJumps;

	if (iStreakJumps >= g_iCurrentJumps)
	{
		float HackRatio = CurStreak.iHackJumps / float(iStreakJumps);
		float HyperRatio = CurStreak.iHyperJumps / float(iStreakJumps);

		if (HackRatio >= g_fCurrentHack && g_fCurrentHack > 0.0)
		{
			HandleFlagging(client, STREAK_HACK);
			return;
		}

		if (HyperRatio >= g_fCurrentHyper && g_fCurrentHyper > 0.0)
		{
			HandleFlagging(client, STREAK_HYPER);
			return;
		}
	}

	if (iGlobalJumps >= g_iGlobalJumps)
	{
		float HackRatio = Player.iHackJumps / float(iGlobalJumps);
		float HyperRatio = Player.iHyperJumps / float(iGlobalJumps);

		if (HackRatio >= g_fGlobalHack && g_fGlobalHack > 0.0)
		{
			HandleFlagging(client, GLOBAL_HACK);
			return;
		}

		if (HyperRatio >= g_fGlobalHyper && g_fGlobalHyper > 0.0)
		{
			HandleFlagging(client, GLOBAL_HYPER);
			return;
		}
	}
}

void HandleFlagging(int client, const char[] reason)
{
	g_iFlagged[client]++;

	// Only notify suspected players once
	if (g_iFlagged[client] == 1)
	{
		NotifyAdmins(client, reason, false);
		ResetValues(client);
		return;
	}

	// Player is now flagged - Flag him only once
	if (!g_bFlagged[client] && g_iFlagged[client] >= g_iMaxFlags)
	{
		g_bFlagged[client] = true;
		NotifyAdmins(client, reason, true);
		Forward_OnDetected(client, reason, g_sStats);
		ResetValues(client);

		if (strcmp(reason, STREAK_HACK, false) == 0 && g_bCurrentHackKick || strcmp(reason, GLOBAL_HACK, false) == 0 && g_bGlobalHackKick)
		{
			LogAction(-1, client, "[AntiBhopCheat] \"%L\" was kicked for using %s", client, reason);
			KickClient(client, "Turn off your hack!");
			return;
		}
	#if defined _SelectiveBhop_Included
		else
		{
			// Limit bhop if applicable
			bool bIsBhopLimited = CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "IsBhopLimited") == FeatureStatus_Available;
			bool bLimitBhop = CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "LimitBhop") == FeatureStatus_Available;

			if (g_Plugin_SelectiveBhop && bLimitBhop && bIsBhopLimited && !IsBhopLimited(client) &&
				(strcmp(reason, STREAK_HYPER, false) == 0 && g_bCurrentStreakHyperLimited || strcmp(reason, GLOBAL_HYPER, false) == 0 && g_bGlobalStreakHyperLimited || 
				strcmp(reason, STREAK_HACK, false) == 0 && g_bCurrentHackHyperLimited || strcmp(reason ,GLOBAL_HACK, false) == 0 && g_bGlobalHackHyperLimited))
			{
				LimitBhop(client, true);
				CPrintToChat(client, "{green}[SM]{red} Your jump settings appear to not be legit.");
				CPrintToChat(client, "{green}[SM]{red} Your bhop has been {fullred}turned off{red} until the end of the map.");
				NotifyAdmins(client, "", false, true);
			}
		}
	#endif
	}
}

void NotifyAdmins(int client, const char[] sReason, bHighSus = false, bLimitBhop = false)
{
	int iUserID = GetClientUserId(client);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && CheckCommandAccess(i, "sm_stats", ADMFLAG_BAN))
		{
			if (bLimitBhop)
			{
				CPrintToChat(i, "{green}[SM] {red}The bhop of {olive}%N {red}has been turned off{default} until the end of the map.", client);
				return;
			}

			CPrintToChat(i, "{green}[SM] {olive}%N %s suspected of using %s", client, bHighSus ? "{red}is highly" : "{orange}is", sReason);
			CPrintToChat(i, "{green}[SM] {red}Spectate {orange}the player by typing {red}/spec #%d", iUserID);
			CPrintToChat(i, "{green}[SM] {fullred}Do not take any actions %s", bHighSus ? "until the player has been spectated and you are 100% sure of the cheat" : "yet");

			PrintStats(i, client);
			PrintStreak(i, client, -1, true);

			if (bHighSus && g_bNoSound)
			{
				if (gEV_Type == Engine_CSS || gEV_Type == Engine_TF2)
					EmitSoundToClient(i, g_sBeepSound);
				else
					ClientCommand(i, "play */%s", g_sBeepSound);
			}
		}
	}

	// Fully reset player stats. We want to analyse a new whole streak.
	CreateTimer(0.3, Timer_OnDetected, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_OnDetected(Handle timer, any client)
{
	if (!client)
		return Plugin_Stop;

	ResetPlayerData(client);
	return Plugin_Continue;
}

public Action Command_Stats(int client, int argc)
{
	if (argc < 1 || argc > 2)
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

	if ((iTargetCount = ProcessTargetString(sArg, client, iTargets, MAXPLAYERS,
		COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for (int i = 0; i < iTargetCount; i++)
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
	if (!hStreak.bValid)
	{
		if (iStreaks)
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
	if (argc < 1 || argc > 2)
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

	if (argc == 2)
	{
		GetCmdArg(2, sArg2, sizeof(sArg2));
		iStreak = StringToInt(sArg2);
	}

	if ((iTargetCount = ProcessTargetString(sArg, client, iTargets, MAXPLAYERS,
		COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for (int i = 0; i < iTargetCount; i++)
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
		FormatEx(g_sStats, sizeof(g_sStats), "%sBunnyhop streak %d for %L\n",
		g_sStats, iStreak, iTarget);

	CPlayer Player = g_aPlayers[iTarget];
	ArrayList hStreaks = Player.hStreaks;
	CStreak hStreak = Player.hStreak;
	int iStreaks = hStreaks.Length;

	// Try showing latest valid streak
	if (iStreak <= 0 && !hStreak.bValid)
	{
		if (iStreaks)
			hStreak = hStreaks.Get(iStreaks - 1);
	}
	else if (iStreak > 0)
	{
		if (iStreak > MAX_STREAKS)
		{
			CReplyToCommand(client, "{green}[SM] {default}Streak is out of bounds (max. %d)!", MAX_STREAKS);
			return;
		}

		int iIndex = iStreaks - iStreak;
		if (iIndex < 0)
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
		FormatEx(g_sStats, sizeof(g_sStats), "%sStreak jumps: %d | Hyper?: %.1f%% | Hack?: %.1f%%\n",
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
		FormatEx(g_sStats, sizeof(g_sStats), "%s#%2s %5s %7s %7s %5s %5s %8s %4s %6s   %s\n",
		g_sStats, "id", " diff", "  invel", " outvel", " gain", " comb", " avgdist", " num", " avg+-", "pattern");

	ArrayList hJumps = hStreak.hJumps;
	float fPrevVel = 0.0;
	int iPrevEndTick = -1;

	for (int i = 0; i < hJumps.Length; i++)
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

		if (iPrevEndTick != -1)
		{
			iTicks = hJump.iStartTick - iPrevEndTick;
			for (int k = 0; k < iTicks && k < 16; k++)
				sPattern[iPatternLen++] = '|';
		}

		float fAvgDist = 0.0;
		float fAvgDownUp = 0.0;

		int iPresses = hPresses.Length;
		for (int j = 0; j < iPresses; j++)
		{
			int aJunkJump[2];
			hPresses.GetArray(j, aJunkJump);

			if (iPrevTick != -1)
			{
				iTicks = aJunkJump[0] - iPrevTick;
				for (int k = 0; k < iTicks && k < 16; k++)
					sPattern[iPatternLen++] = '.';

				fAvgDist += iTicks;
			}

			sPattern[iPatternLen++] = '^';

			iTicks = aJunkJump[1] - aJunkJump[0];
			for (int k = 0; k < iTicks && k < 16; k++)
				sPattern[iPatternLen++] = ',';

			fAvgDownUp += iTicks;

			sPattern[iPatternLen++] = 'v';

			iPrevTick = aJunkJump[1];
		}

		fAvgDist /= iPresses;
		fAvgDownUp /= iPresses;

		iTicks = iEndTick - iPrevTick;
		for (int k = 0; k < iTicks && k < 16; k++)
			sPattern[iPatternLen++] = '.';

		sPattern[iPatternLen++] = '|';
		sPattern[iPatternLen++] = '\0';

		if (fPrevVel == 0.0)
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
			FormatEx(g_sStats, sizeof(g_sStats), "%s#%2d %4d%% %7.1f %7.1f %4d%% %4d%% %8.2f %4d %6.2f   %s\n",
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

void Forward_OnDetected(int client, const char[] reason, const char[] stats)
{
	Call_StartForward(g_hOnClientDetected);
	Call_PushCell(client);
	Call_PushString(reason);
	Call_PushString(stats);
	Call_Finish();

	g_sStats = "";
}

stock void InitPlayerData(int client)
{
	g_aPlayers[client] = new CPlayer(client);
	ResetValues(client);
}

stock void DeletePlayerData(int client)
{
	if (g_aPlayers[client] != null)
	{
		g_aPlayers[client].Dispose();
		g_aPlayers[client] = null;
	}
}

stock void ResetValues(int client)
{
	g_bOnGround[client] = false;
	g_bHoldingJump[client] = false;
	g_bInJump[client] = false;
}

stock void ResetPlayerData(int client)
{
	DeletePlayerData(client);
	InitPlayerData(client);
}
