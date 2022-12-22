#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2items>

// todo: !hide players (should i implement this here or in bhop timer?)
// todo: (bhop timer) remove jumps, or reimplement to use detjumps
// todo: (bhop timer) show +attack(2) in !keys

#define VERSION "1.0.2"

#define MAP_NAME "jump_pyrokinesis_rc1"

// There's a higher chance Valve will break the signature for CBaseWeapon::GetSlot in a random update than add a new weapon to the game
// Might as well hardcode all of Pyro's secondaries to save myself the trouble of reverse-engineering TF2 every few weeks
// 351 is the Detonator
#define PYRO_SECONDARIES 12, 39, 199, /*351,*/ 415, 595, 740, 1081, 1141, 1153, 1179, 1180, 15003, 15016, 15044, 15047, 15085, 15109, 15132, 15133, 15152

public Plugin myinfo =
{
	name = "Pyrokinesis Manager",
	author = "brokenphilip",
	description = "Sets the server up for the Pyrokinesis jump map",
	version = VERSION,
	url = "https://github.com/brokenphilip/bhoptimer-pyrokinesis"
};

bool isJumpPK = false;
//Handle hDetonator;

// Natives/Defines from shavit-hud (can't include just the hud)
#define HUD_CENTER (1 << 1)
native int Shavit_GetHUDSettings(int client);
native void Shavit_ToggleHUD(int client, int hud);

public void OnPluginStart()
{
	AddNormalSoundHook(NormalSoundHook);

	// Account for late plugin load
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);

			char mapname[128];
			GetCurrentMap(mapname, sizeof(mapname));
			isJumpPK = StrEqual(mapname, MAP_NAME, false);

			// This sucks, but if you're late-loading this to begin with you're evil
			if (isJumpPK && IsPlayerAlive(i)) ForcePlayerSuicide(i);
		}
	}

	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
	HookEvent("player_activate", Event_Activate, EventHookMode_Post);

	RegConsoleCmd("sm_fix", Command_Fix, "Attempts to fix the hint HUD.");

	/*

	hDetonator = TF2Items_CreateItem(PRESERVE_ATTRIBUTES);

	TF2Items_SetClassname(hDetonator, "tf_weapon_flaregun");
	TF2Items_SetItemIndex(hDetonator, 351);
	TF2Items_SetQuality(hDetonator, 6);
	TF2Items_SetLevel(hDetonator, 10);
	//TF2Items_SetNumAttributes(hDetonator, 0);

	//TF2Items_SetNumAttributes(hDetonator, 6);
	//TF2Items_SetAttribute(hDetonator, 0, 25, 0.5);
	//TF2Items_SetAttribute(hDetonator, 1, 207, 1.50);
	//TF2Items_SetAttribute(hDetonator, 2, 1, 0.75);
	//TF2Items_SetAttribute(hDetonator, 3, 209, 1.0);
	//TF2Items_SetAttribute(hDetonator, 4, 144, 1.0);
	//TF2Items_SetAttribute(hDetonator, 5, 551, 1.0);

	*/
}

public Action NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (isJumpPK)
	{
		if (StrContains(sample, "vo/pyro_Pain", false) != -1 ||
		    StrContains(sample, "vo/pyro_AutoOnFire", false) != -1)
			return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Command_Fix(int client, int args)
{
	if (isJumpPK)
	{
		ReplyToCommand(client, "[SM] Attempting fix, try hud_reloadscheme if unsuccessful.");
		FixHUD(client);
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));

	// TODO: use a config file/keyvalues instead of hardcoding
	isJumpPK = StrEqual(mapname, MAP_NAME, false);
	if (!isJumpPK)
	{
		LogMessage("Pyrokinesis not detected, disabling shavit's bhop timer...");
		// TODO: why are we not unloading these?
		//ServerCommand("sm plugins unload shavit-core");
		//ServerCommand("sm plugins unload shavit-zones");
		//ServerCommand("sm plugins unload shavit-wr");
		ServerCommand("sm plugins unload shavit-hud");
	}
	else
	{
		LogMessage("Pyrokinesis detected, modifications active.");
		// (block plugins on pyrokinesis here)
	}
}

// Removing the resupply zones, because loadout changes allow faster refire to gain an unfair advantage.
// Mandatory compromises:
// - handle OnGiveNamedItem differently?
// - remove fall damage
// - remove self damage
// - give the Detonator infinite ammo OR ammo regen
public void OnEntityCreated(int entity, const char[] classname)
{
	// !!! Must wait for the entity to spawn before killing it
	if (isJumpPK && StrEqual(classname, "func_regenerate")) SDKHook(entity, SDKHook_Spawn, Hook_OnResupEntSpawn); 
} 

public Action Hook_OnResupEntSpawn(int entity)
{
	// Prevent it from spawning
	return Plugin_Handled; 
} 

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void Event_Spawn(Event event, char[] name, bool dontBroadcast)
{
	if (isJumpPK)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		// player_spawn activates before we've picked a team too (fucking why), bail if so
		if (GetClientTeam(client) < 2)
			return;

		TFClassType class = TF2_GetPlayerClass(client);
		if (class != TFClass_Pyro)
		{
			PrintToChat(client, "[SM] You can only play Pyro on this map.");
			TF2_SetPlayerClass(client, TFClass_Pyro);
			TF2_RespawnPlayer(client);
			return;
		}

		// If they have the center hud enabled, briefly toggle it off and back on again
		// This should fix *most* hint text disappearances
		// Ideally, we should internally replace the shitty hint hud with something more stable if possible 
		FixHUD(client);

		// Make enemies pass through each other
		SetEntityCollisionGroup(client, 2);

		// Wait until the weapons are stripped in OnGiveNamedItem, then force-equip the Detonator
		CreateTimer(0.1, EquipDet, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void FixHUD(int client)
{
	if (LibraryExists("shavit-hud") && (Shavit_GetHUDSettings(client) & HUD_CENTER) == HUD_CENTER)
	{
		// This ToggleHUD native does NOT notify the player NOR set cookies
		Shavit_ToggleHUD(client, HUD_CENTER);
		CreateTimer(1.0, ToggleHUD2, client);
	}
}

public Action ToggleHUD2(Handle timer, int client)
{
	if(IsClientInGame(client)) Shavit_ToggleHUD(client, HUD_CENTER);

	return Plugin_Continue;
}

public Action EquipDet(Handle timer, int client)
{
	FakeClientCommand(client, "use tf_weapon_flaregun");

	return Plugin_Continue;
}

public void Event_Activate(Event event, const char[] name, bool dontBroadcast)
{
	if (isJumpPK)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		CreateTimer(10.0, CmdHelpAd, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action CmdHelpAd(Handle timer, int client)
{
	PrintToChat(client, "[SM] Commands: !wr for records on A (go to !main), !bwr 1 to 4 for records on B-F (go to !b1 to !b4)");
	PrintToChat(client, "[SM] If the HUD is broken (gray square in the middle), type !fix");

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// No damage between enemies
	if (isJumpPK && victim != attacker)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int index, int level, int quality, int entity)
{
	if (isJumpPK)
	{
		if (index == 351)
		{
			TF2Attrib_SetByName(entity, "cancel falling damage", 1.0);
			TF2Attrib_SetByName(entity, "blast dmg to self increased", 0.001);
			TF2Attrib_SetByName(entity, "ammo regen", 1.0);
		}

		// If it's not the Detonator or a cosmetic
		else if (!StrEqual(classname, "tf_wearable", false))
		{
			TF2_RemoveWeaponByEnt(client, entity);

			switch (index)
			{
				case PYRO_SECONDARIES: 
				{
					// Does not work for some reason, despite working just fine before
					//TF2Items_GiveNamedItem(client, hDetonator);

					// Don't like this, but it doesn't work either
					//TF2Items_GiveWeapon(client, 351);

					// Fuck me sideways
					ServerCommand("sm_givew #%d 351", GetClientUserId(client));
				}
			}
		}
	}
}

stock void TF2_RemoveWeaponByEnt(int client, int ent)
{
	if (IsValidEntity(ent))
	{
		// Canteens do not have extra wearable netprops
		// This does not apply to spellbooks or other action items (wtf)
		if (HasEntProp(ent, Prop_Send, "m_hExtraWearable"))
		{
			int extraWearable = GetEntPropEnt(ent, Prop_Send, "m_hExtraWearable");
			if (extraWearable != -1) TF2_RemoveWearable(client, extraWearable);

			extraWearable = GetEntPropEnt(ent, Prop_Send, "m_hExtraWearableViewModel");
			if (extraWearable != -1) TF2_RemoveWearable(client, extraWearable);
		}

		RemovePlayerItem(client, ent);
		AcceptEntityInput(ent, "Kill");
	}
}