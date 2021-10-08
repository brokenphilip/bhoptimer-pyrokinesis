
bool gB_StyleCommandsRegistered = false;
int gI_Styles = 0;
int gI_OrderedStyles[STYLE_LIMIT];
StringMap gSM_StyleKeys[STYLE_LIMIT];
StringMap gSM_StyleCommands = null;
int gI_CurrentParserIndex = 0;

void Shavit_Style_Settings_Natives()
{
	CreateNative("Shavit_GetOrderedStyles", Native_GetOrderedStyles);
	CreateNative("Shavit_GetStyleCount", Native_GetStyleCount);

	CreateNative("Shavit_GetStyleSetting", Native_GetStyleSetting);
	CreateNative("Shavit_GetStyleSettingInt", Native_GetStyleSettingInt);
	CreateNative("Shavit_GetStyleSettingBool", Native_GetStyleSettingBool);
	CreateNative("Shavit_GetStyleSettingFloat", Native_GetStyleSettingFloat);

	CreateNative("Shavit_HasStyleSetting", Native_HasStyleSetting);

	CreateNative("Shavit_SetStyleSetting", Native_SetStyleSetting);
	CreateNative("Shavit_SetStyleSettingInt", Native_SetStyleSettingInt);
	CreateNative("Shavit_SetStyleSettingBool", Native_SetStyleSettingBool);
	CreateNative("Shavit_SetStyleSettingFloat", Native_SetStyleSettingFloat);

	CreateNative("Shavit_GetStyleStrings", Native_GetStyleStrings);
	CreateNative("Shavit_GetStyleStringsStruct", Native_GetStyleStringsStruct);
}

bool LoadStyles()
{
	delete gSM_StyleCommands;
	gSM_StyleCommands = new StringMap();

	for (int i = 0; i < STYLE_LIMIT; i++)
	{
		delete gSM_StyleKeys[i];
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-styles.cfg");

	SMCParser parser = new SMCParser();
	parser.OnEnterSection = OnStyleEnterSection;
	parser.OnLeaveSection = OnStyleLeaveSection;
	parser.OnKeyValue = OnStyleKeyValue;
	parser.ParseFile(sPath);
	delete parser;

	for (int i = 0; i < gI_Styles; i++)
	{
		if (gSM_StyleKeys[i] == null)
		{
			SetFailState("Missing style index %d. Highest index is %d. Fix addons/sourcemod/configs/shavit-styles.cfg", i, gI_Styles-1);
		}
	}

	gB_StyleCommandsRegistered = true;

	SortCustom1D(gI_OrderedStyles, gI_Styles, SortAscending_StyleOrder);

	Call_StartForward(gH_Forwards_OnStyleConfigLoaded);
	Call_PushCell(gI_Styles);
	Call_Finish();

	return true;
}

public SMCResult OnStyleEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	// styles key
	if (!IsCharNumeric(name[0]))
	{
		return SMCParse_Continue;
	}

	gI_CurrentParserIndex = StringToInt(name);

	if (gSM_StyleKeys[gI_CurrentParserIndex] != null)
	{
		SetFailState("Style index %d (%s) already parsed. Stop using the same index for multiple styles. Fix addons/sourcemod/configs/shavit-styles.cfg", gI_CurrentParserIndex, name);
	}

	if (gI_CurrentParserIndex >= STYLE_LIMIT)
	{
		SetFailState("Style index %d (%s) too high (limit %d). Fix addons/sourcemod/configs/shavit-styles.cfg", gI_CurrentParserIndex, name, STYLE_LIMIT);
	}

	if (gI_Styles <= gI_CurrentParserIndex)
	{
		gI_Styles = gI_CurrentParserIndex + 1;
	}

	gSM_StyleKeys[gI_CurrentParserIndex] = new StringMap();

	SetStyleSetting(gI_CurrentParserIndex, "name", "<MISSING STYLE NAME>");
	SetStyleSetting(gI_CurrentParserIndex, "shortname", "<MISSING SHORT STYLE NAME>");
	SetStyleSetting(gI_CurrentParserIndex, "htmlcolor", "<MISSING STYLE HTML COLOR>");
	SetStyleSetting(gI_CurrentParserIndex, "command", "");
	SetStyleSetting(gI_CurrentParserIndex, "clantag", "<MISSING STYLE CLAN TAG>");
	SetStyleSetting(gI_CurrentParserIndex, "specialstring", "");
	SetStyleSetting(gI_CurrentParserIndex, "permission", "");

	SetStyleSettingInt  (gI_CurrentParserIndex, "autobhop", 1);
	SetStyleSettingInt  (gI_CurrentParserIndex, "easybhop", 1);
	SetStyleSettingInt  (gI_CurrentParserIndex, "prespeed", 0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "velocity_limit", 0.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "airaccelerate", 1000.0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "bunnyhopping", 1);
	SetStyleSettingFloat(gI_CurrentParserIndex, "runspeed", 260.00);
	SetStyleSettingFloat(gI_CurrentParserIndex, "gravity", 1.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "speed", 1.0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "halftime", 0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "timescale", 1.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "velocity", 1.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "bonus_velocity", 0.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "min_velocity", 0.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "jump_multiplier", 0.0);
	SetStyleSettingFloat(gI_CurrentParserIndex, "jump_bonus", 0.0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_w", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_a", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_s", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_d", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_use", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "force_hsw", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_pleft", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_pright", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "block_pstrafe", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "unranked", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "noreplay", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "sync", 1);
	SetStyleSettingInt  (gI_CurrentParserIndex, "strafe_count_w", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "strafe_count_a", 1);
	SetStyleSettingInt  (gI_CurrentParserIndex, "strafe_count_s", 0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "strafe_count_d", 1);
	SetStyleSettingFloat(gI_CurrentParserIndex, "rankingmultiplier", 1.0);
	SetStyleSettingInt  (gI_CurrentParserIndex, "special", 0);

	SetStyleSettingInt(gI_CurrentParserIndex, "ordering", gI_CurrentParserIndex);

	SetStyleSettingInt(gI_CurrentParserIndex, "inaccessible", 0);
	SetStyleSettingInt(gI_CurrentParserIndex, "enabled", 1);
	SetStyleSettingInt(gI_CurrentParserIndex, "kzcheckpoints", 0);
	SetStyleSettingInt(gI_CurrentParserIndex, "force_groundkeys", 0);

	gI_OrderedStyles[gI_CurrentParserIndex] = gI_CurrentParserIndex;

	return SMCParse_Continue;
}

public SMCResult OnStyleLeaveSection(SMCParser smc)
{
	if (gI_CurrentParserIndex == -1)
	{
		// OnStyleLeaveSection can be called back to back.
		// And does for when hitting the last style!
		// So we set gI_CurrentParserIndex to -1 at the end of this function.
		return;
	}

	// if this style is disabled, we will force certain settings
	if (GetStyleSettingInt(gI_CurrentParserIndex, "enabled") <= 0)
	{
		SetStyleSettingInt  (gI_CurrentParserIndex, "noreplay", 1);
		SetStyleSettingFloat(gI_CurrentParserIndex, "rankingmultiplier", 0.0);
		SetStyleSettingInt  (gI_CurrentParserIndex, "inaccessible", 1);
	}

	if (GetStyleSettingBool(gI_CurrentParserIndex, "halftime"))
	{
		SetStyleSettingFloat(gI_CurrentParserIndex, "timescale", 0.5);
	}

	if (GetStyleSettingFloat(gI_CurrentParserIndex, "timescale") <= 0.0)
	{
		SetStyleSettingFloat(gI_CurrentParserIndex, "timescale", 1.0);
	}

	// Setting it here so that we can reference the timescale setting.
	if (!HasStyleSetting(gI_CurrentParserIndex, "force_timescale"))
	{
		if (GetStyleSettingFloat(gI_CurrentParserIndex, "timescale") == 1.0)
		{
			SetStyleSettingInt(gI_CurrentParserIndex, "force_timescale", 0);
		}
		else
		{
			SetStyleSettingInt(gI_CurrentParserIndex, "force_timescale", 1);
		}
	}

	char sStyleCommand[128];
	GetStyleSetting(gI_CurrentParserIndex, "command", sStyleCommand, sizeof(sStyleCommand));
	char sName[64];
	GetStyleSetting(gI_CurrentParserIndex, "name", sName, sizeof(sName));

	if (!gB_StyleCommandsRegistered && strlen(sStyleCommand) > 0 && !GetStyleSettingBool(gI_CurrentParserIndex, "inaccessible"))
	{
		char sStyleCommands[32][32];
		int iCommands = ExplodeString(sStyleCommand, ";", sStyleCommands, 32, 32, false);

		char sDescription[128];
		FormatEx(sDescription, 128, "Change style to %s.", sName);

		for (int x = 0; x < iCommands; x++)
		{
			TrimString(sStyleCommands[x]);
			StripQuotes(sStyleCommands[x]);

			char sCommand[32];
			FormatEx(sCommand, 32, "sm_%s", sStyleCommands[x]);

			gSM_StyleCommands.SetValue(sCommand, gI_CurrentParserIndex);

			RegConsoleCmd(sCommand, Command_StyleChange, sDescription);
		}
	}

	char sPermission[64];
	GetStyleSetting(gI_CurrentParserIndex, "name", sPermission, sizeof(sPermission));

	if (StrContains(sPermission, ";") != -1)
	{
		char sText[2][32];
		int iCount = ExplodeString(sPermission, ";", sText, 2, 32);

		AdminFlag flag = Admin_Reservation;

		if(FindFlagByChar(sText[0][0], flag))
		{
			gI_StyleFlag[gI_CurrentParserIndex] = FlagToBit(flag);
		}

		strcopy(gS_StyleOverride[gI_CurrentParserIndex], 32, (iCount >= 2)? sText[1]:"");
	}
	else if (strlen(sPermission) > 0)
	{
		AdminFlag flag = Admin_Reservation;

		if(FindFlagByChar(sPermission[0], flag))
		{
			gI_StyleFlag[gI_CurrentParserIndex] = FlagToBit(flag);
		}
	}

	gI_CurrentParserIndex = -1;
}

public SMCResult OnStyleKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	SetStyleSetting(gI_CurrentParserIndex, key, value);
}

public int SortAscending_StyleOrder(int index1, int index2, const int[] array, any hndl)
{
	return GetStyleSettingInt(index1, "ordering") - GetStyleSettingInt(index2, "ordering");
}

public Action Command_StyleChange(int client, int args)
{
	char sCommand[128];
	GetCmdArg(0, sCommand, 128);

	int style = 0;

	if (gSM_StyleCommands.GetValue(sCommand, style))
	{
		ChangeClientStyle(client, style, true);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public int Native_GetStyleCount(Handle handler, int numParams)
{
	return (gI_Styles > 0)? gI_Styles:-1;
}

public int Native_GetOrderedStyles(Handle handler, int numParams)
{
	return SetNativeArray(1, gI_OrderedStyles, GetNativeCell(2));
}

public int Native_GetStyleSetting(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	int maxlength = GetNativeCell(4);
	
	char sValue[128];
	bool ret = GetStyleSetting(style, sKey, sValue, sizeof(sValue));

	SetNativeString(3, sValue, maxlength);
	return ret;
}

bool GetStyleSetting(int style, const char[] key, char[] value, int size)
{
	style_setting_t ss;

	if (gSM_StyleKeys[style].GetArray(key, ss, sizeof(ss)))
	{
		strcopy(value, size, ss.str);
		return true;
	}

	return false;
}

public int Native_GetStyleSettingInt(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	return GetStyleSettingInt(style, sKey);
}

int GetStyleSettingInt(int style, char[] key)
{
	style_setting_t ss;
	gSM_StyleKeys[style].GetArray(key, ss, style_setting_t::i+1);
	return ss.i;
}

public int Native_GetStyleSettingBool(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingBool(style, sKey);
}

bool GetStyleSettingBool(int style, char[] key)
{
	return GetStyleSettingInt(style, key) != 0;
}

public any Native_GetStyleSettingFloat(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	return GetStyleSettingFloat(style, sKey);
}

float GetStyleSettingFloat(int style, char[] key)
{
	style_setting_t ss;
	gSM_StyleKeys[style].GetArray(key, ss, style_setting_t::f+1);
	return ss.f;
}

public any Native_HasStyleSetting(Handle handler, int numParams)
{
	// TODO: replace with sm 1.11 StringMap.ContainsKey
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	return HasStyleSetting(style, sKey);
}

bool HasStyleSetting(int style, char[] key)
{
	int value[1];
	return gSM_StyleKeys[style].GetArray(key, value, 1);
}

bool SetStyleSetting(int style, const char[] key, const char[] value, bool replace=true)
{
	style_setting_t ss;
	ss.i = StringToInt(value);
	ss.f = StringToFloat(value);
	int strcells = strcopy(ss.str, sizeof(ss.str), value);
	if (strcells < 1) strcells = 1;
	return gSM_StyleKeys[style].SetArray(key, ss, strcells+2, replace);
}

public any Native_SetStyleSetting(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	char sValue[128];
	GetNativeString(3, sValue, sizeof(sValue));

	bool replace = GetNativeCell(4);

	return SetStyleSetting(style, sKey, sValue, replace);
}

public any Native_SetStyleSettingFloat(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	float fValue = GetNativeCell(3);

	bool replace = GetNativeCell(4);

	return SetStyleSettingFloat(style, sKey, fValue, replace);
}

bool SetStyleSettingFloat(int style, char[] key, float value, bool replace=true)
{
	style_setting_t ss;
	ss.i = RoundFloat(value);
	ss.f = value;
	int strcells = FloatToString(value, ss.str, sizeof(ss.str));
	return gSM_StyleKeys[style].SetArray(key, ss, strcells+2, replace);
}

public any Native_SetStyleSettingBool(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	bool value = GetNativeCell(3);

	bool replace = GetNativeCell(4);

	return SetStyleSettingBool(style, sKey, value, replace);
}

bool SetStyleSettingBool(int style, char[] key, bool value, bool replace=true)
{
	return SetStyleSettingInt(style, key, value ? 1 : 0, replace);
}

public any Native_SetStyleSettingInt(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[64];
	GetNativeString(2, sKey, sizeof(sKey));

	int value = GetNativeCell(3);

	bool replace = GetNativeCell(4);

	return SetStyleSettingInt(style, sKey, value, replace);
}

bool SetStyleSettingInt(int style, char[] key, int value, bool replace=true)
{
	style_setting_t ss;
	ss.i = value;
	ss.f = float(value);
	int strcells = IntToString(value, ss.str, sizeof(ss.str));
	return gSM_StyleKeys[style].SetArray(key, ss, strcells+2, replace);
}

public int Native_GetStyleStrings(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int type = GetNativeCell(2);
	int size = GetNativeCell(4);
	char sValue[128];

	switch(type)
	{
		case sStyleName:
		{
			GetStyleSetting(style, "name", sValue, size);
		}
		case sShortName:
		{
			GetStyleSetting(style, "shortname", sValue, size);
		}
		case sHTMLColor:
		{
			GetStyleSetting(style, "htmlcolor", sValue, size);
		}
		case sChangeCommand:
		{
			GetStyleSetting(style, "command", sValue, size);
		}
		case sClanTag:
		{
			GetStyleSetting(style, "clantag", sValue, size);
		}
		case sSpecialString:
		{
			GetStyleSetting(style, "specialstring", sValue, size);
		}
		case sStylePermission:
		{
			GetStyleSetting(style, "permission", sValue, size);
		}
		default:
		{
			return -1;
		}
	}

	return SetNativeString(3, sValue, size);
}

public int Native_GetStyleStringsStruct(Handle plugin, int numParams)
{
	int style = GetNativeCell(1);

	if (GetNativeCell(3) != sizeof(stylestrings_t))
	{
		return ThrowNativeError(200, "stylestrings_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins", GetNativeCell(3), sizeof(stylestrings_t));
	}

	stylestrings_t strings;
	GetStyleSetting(style, "name", strings.sStyleName, sizeof(strings.sStyleName));
	GetStyleSetting(style, "shortname", strings.sShortName, sizeof(strings.sShortName));
	GetStyleSetting(style, "htmlcolor", strings.sHTMLColor, sizeof(strings.sHTMLColor));
	GetStyleSetting(style, "command", strings.sChangeCommand, sizeof(strings.sChangeCommand));
	GetStyleSetting(style, "clantag", strings.sClanTag, sizeof(strings.sClanTag));
	GetStyleSetting(style, "specialstring", strings.sSpecialString, sizeof(strings.sSpecialString));
	GetStyleSetting(style, "permission", strings.sStylePermission, sizeof(strings.sStylePermission));

	return SetNativeArray(2, strings, sizeof(stylestrings_t));
}