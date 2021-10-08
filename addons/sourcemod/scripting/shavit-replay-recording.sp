/*
 * shavit's Timer - Replay Recorder
 * by: shavit
 *
 * This file is part of shavit's Timer.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <sourcemod>

#include <shavit>

#include <shavit/shavit-replay-stocks>

public Plugin myinfo =
{
	name = "[shavit] Replay Recorder",
	author = "shavit",
	description = "A replay recorder for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

bool gB_Late = false;
EngineVersion gEV_Type = Engine_Unknown;

char gS_ReplayFolder[PLATFORM_MAX_PATH];

Convar gCV_Enabled = null;
Convar gCV_PlaybackPostRunTime = null;
Convar gCV_PlaybackPreRunTime = null;
Convar gCV_PreRunAlways = null;
Convar gCV_TimeLimit = null;

Handle gH_ShouldSaveReplayCopy = null;
Handle gH_OnReplaySaved = null;

// stuff related to postframes
finished_run_info gA_FinishedRunInfo[MAXPLAYERS+1];
bool gB_GrabbingPostFrames[MAXPLAYERS+1];
Handle gH_PostFramesTimer[MAXPLAYERS+1];
int gI_PlayerFinishFrame[MAXPLAYERS+1];

// we use gI_PlayerFrames instead of grabbing gA_PlayerFrames.Length because the ArrayList is resized to handle 2s worth of extra frames to reduce how often we have to resize it
int gI_PlayerFrames[MAXPLAYERS+1];
int gI_PlayerPrerunFrames[MAXPLAYERS+1];
ArrayList gA_PlayerFrames[MAXPLAYERS+1];
float gF_NextFrameTime[MAXPLAYERS+1];

int gI_HijackFrames[MAXPLAYERS+1];
float gF_HijackedAngles[MAXPLAYERS+1][2];


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_GetClientFrameCount", Native_GetClientFrameCount);
	CreateNative("Shavit_GetPlayerPreFrames", Native_GetPlayerPreFrames);
	CreateNative("Shavit_GetReplayData", Native_GetReplayData);
	CreateNative("Shavit_HijackAngles", Native_HijackAngles);
	CreateNative("Shavit_SetReplayData", Native_SetReplayData);
	CreateNative("Shavit_SetPlayerPreFrames", Native_SetPlayerPreFrames);

	RegPluginLibrary("shavit-replay-humans");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	gH_ShouldSaveReplayCopy = CreateGlobalForward("Shavit_ShouldSaveReplayCopy", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_OnReplaySaved = CreateGlobalForward("Shavit_OnReplaySaved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_String);

	gCV_Enabled = new Convar("shavit_replay_recording_enabled", "1", "Enable replay bot functionality?", 0, true, 0.0, true, 1.0);
	gCV_PlaybackPostRunTime = new Convar("shavit_replay_postruntime", "1.5", "Time (in seconds) to record after a player enters the end zone.", 0, true, 0.0, true, 2.0);
	gCV_PreRunAlways = new Convar("shavit_replay_prerun_always", "1", "Record prerun frames outside the start zone?", 0, true, 0.0, true, 1.0);
	gCV_PlaybackPreRunTime = new Convar("shavit_replay_preruntime", "1.5", "Time (in seconds) to record before a player leaves start zone.", 0, true, 0.0, true, 2.0);
	gCV_TimeLimit = new Convar("shavit_replay_timelimit", "7200.0", "Maximum amount of time (in seconds) to allow saving to disk.\nDefault is 7200 (2 hours)\n0 - Disabled");
}

bool LoadReplayConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-replay.cfg");

	KeyValues kv = new KeyValues("shavit-replay");
	
	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	char sFolder[PLATFORM_MAX_PATH];
	kv.GetString("replayfolder", sFolder, PLATFORM_MAX_PATH, "{SM}/data/replaybot");

	if(StrContains(sFolder, "{SM}") != -1)
	{
		ReplaceString(sFolder, PLATFORM_MAX_PATH, "{SM}/", "");
		BuildPath(Path_SM, sFolder, PLATFORM_MAX_PATH, "%s", sFolder);
	}
	
	strcopy(gS_ReplayFolder, PLATFORM_MAX_PATH, sFolder);

	delete kv;

	return true;
}

public void OnMapStart()
{
	if (!LoadReplayConfig())
	{
		SetFailState("Could not load the replay bots' configuration file. Make sure it exists (addons/sourcemod/configs/shavit-replay.cfg) and follows the proper syntax!");
	}

	GetLowercaseMapName(gS_Map);

	Shavit_Replay_CreateDirectories(gS_ReplayFolder, gI_Styles);
}

public void OnClientPutInServer(int client)
{
	ClearFrames(client);
}

public void OnClientDisconnect(int client)
{
	if (gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}
}

public void OnClientDisconnect_Post(int client)
{
	// This runs after shavit-misc has cloned the handle
	delete gA_PlayerFrames[client];
}

void ClearFrames(int client)
{
	delete gA_PlayerFrames[client];
	gA_PlayerFrames[client] = new ArrayList(sizeof(frame_t));
	gI_PlayerFrames[client] = 0;
	gF_NextFrameTime[client] = 0.0;
	gI_PlayerPrerunFrames[client] = 0;
	gI_PlayerFinishFrame[client] = 0;
	gI_HijackFrames[client] = 0;
}

public void Shavit_OnTimescaleChanged(int client, float oldtimescale, float newtimescale)
{
	gF_NextFrameTime[client] = 0.0;
}

public Action Shavit_OnStart(int client)
{
	gI_HijackFrames[client] = 0;

	if (gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}

	int iMaxPreFrames = RoundToFloor(gCV_PlaybackPreRunTime.FloatValue * gF_Tickrate / Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(client), "speed"));
	bool bInStart = Shavit_InsideZone(client, Zone_Start, Shavit_GetClientTrack(client));

	if (bInStart)
	{
		int iFrameDifference = gI_PlayerFrames[client] - iMaxPreFrames;

		if (iFrameDifference > 0)
		{
			// For too many extra frames, we'll just shift the preframes to the start of the array.
			if (iFrameDifference > 100)
			{
				for (int i = iFrameDifference; i < gI_PlayerFrames[client]; i++)
				{
					gA_PlayerFrames[client].SwapAt(i, i-iFrameDifference);
				}

				gI_PlayerFrames[client] = iMaxPreFrames;
			}
			else // iFrameDifference isn't that bad, just loop through and erase.
			{
				while (iFrameDifference--)
				{
					gA_PlayerFrames[client].Erase(0);
					gI_PlayerFrames[client]--;
				}
			}
		}
	}
	else
	{
		if (!gCV_PreRunAlways.BoolValue)
		{
			ClearFrames(client);
		}
	}

	gI_PlayerPrerunFrames[client] = gI_PlayerFrames[client];

	return Plugin_Continue;
}

public void Shavit_OnStop(int client)
{
	if (gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}

	ClearFrames(client);
}

public Action Timer_PostFrames(Handle timer, int client)
{
	gH_PostFramesTimer[client] = null;
	FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	return Plugin_Stop;
}

void FinishGrabbingPostFrames(int client, finished_run_info info)
{
	gB_GrabbingPostFrames[client] = false;
	delete gH_PostFramesTimer[client];

	DoReplaySaverCallbacks(info.iSteamID, client, info.style, info.time, info.jumps, info.strafes, info.sync, info.track, info.oldtime, info.perfs, info.avgvel, info.maxvel, info.timestamp, info.fZoneOffset);
}

void DoReplaySaverCallbacks(int iSteamID, int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float perfs, float avgvel, float maxvel, int timestamp, float fZoneOffset[2])
{
	gA_PlayerFrames[client].Resize(gI_PlayerFrames[client]);

	bool isTooLong = (gCV_TimeLimit.FloatValue > 0.0 && time > gCV_TimeLimit.FloatValue);

	float length = GetReplayLength(style, track, gA_FrameCache[style][track]);
	bool isBestReplay = (length == 0.0 || time < length);

	Action action = Plugin_Continue;
	Call_StartForward(gH_ShouldSaveReplayCopy);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(jumps);
	Call_PushCell(strafes);
	Call_PushCell(sync);
	Call_PushCell(track);
	Call_PushCell(oldtime);
	Call_PushCell(perfs);
	Call_PushCell(avgvel);
	Call_PushCell(maxvel);
	Call_PushCell(timestamp);
	Call_PushCell(isTooLong);
	Call_PushCell(isBestReplay);
	Call_Finish(action);

	bool makeCopy = (action != Plugin_Continue);
	bool makeReplay = (isBestReplay && !isTooLong);

	if (!makeCopy && !makeReplay)
	{
		return;
	}

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);
	ReplaceString(sName, MAX_NAME_LENGTH, "#", "?");

	int postframes = gI_PlayerFrames[client] - gI_PlayerFinishFrame[client];

	char sPath[PLATFORM_MAX_PATH];
	SaveReplay(style, track, time, iSteamID, sName, gI_PlayerPrerunFrames[client], gA_PlayerFrames[client], gI_PlayerFrames[client], postframes, timestamp, fZoneOffset, makeCopy, makeReplay, sPath, sizeof(sPath));

	Call_StartForward(gH_OnReplaySaved);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(jumps);
	Call_PushCell(strafes);
	Call_PushCell(sync);
	Call_PushCell(track);
	Call_PushCell(oldtime);
	Call_PushCell(perfs);
	Call_PushCell(avgvel);
	Call_PushCell(maxvel);
	Call_PushCell(timestamp);
	Call_PushCell(isBestReplay);
	Call_PushCell(isTooLong);
	Call_PushCell(makeCopy);
	Call_PushString(sPath);
	Call_PushCell(gA_PlayerFrames[client]);
	Call_PushCell(preframes);
	Call_PushCell(postframes);
	Call_PushString(sName);
	Call_Finish();

	ClearFrames(client);
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float perfs, float avgvel, float maxvel, int timestamp)
{
	if (Shavit_IsPracticeMode(client) || !gCV_Enabled.BoolValue || gI_PlayerFrames[client] == 0)
	{
		return;
	}

	gI_PlayerFinishFrame[client] = gI_PlayerFrames[client];

	float fZoneOffset[2];
	fZoneOffset[0] = Shavit_GetZoneOffset(client, 0);
	fZoneOffset[1] = Shavit_GetZoneOffset(client, 1);

	if (gCV_PlaybackPostRunTime.FloatValue > 0.0)
	{
		finished_run_info info;
		info.iSteamID = GetSteamAccountID(client);
		info.style = style;
		info.time = time;
		info.jumps = jumps;
		info.strafes = strafes;
		info.sync = sync;
		info.track = track;
		info.oldtime = oldtime;
		info.perfs = perfs;
		info.avgvel = avgvel;
		info.maxvel = maxvel;
		info.timestamp = timestamp;
		info.fZoneOffset = fZoneOffset;

		gA_FinishedRunInfo[client] = info;
		gB_GrabbingPostFrames[client] = true;
		delete gH_PostFramesTimer[client];
		gH_PostFramesTimer[client] = CreateTimer(gCV_PlaybackPostRunTime.FloatValue, Timer_PostFrames, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		DoReplaySaverCallbacks(GetSteamAccountID(client), client, style, time, jumps, strafes, sync, track, oldtime, perfs, avgvel, maxvel, timestamp, fZoneOffset);
	}
}

void SaveReplay(int style, int track, float time, int steamid, char[] name, int preframes, ArrayList playerrecording, int iSize, int postframes, int timestamp, float fZoneOffset[2], bool saveCopy, bool saveWR, char[] sPath, int sPathLen)
{
	char sTrack[4];
	FormatEx(sTrack, 4, "_%d", track);

	File fWR = null;
	File fCopy = null;

	if (saveWR)
	{
		FormatEx(sPath, sPathLen, "%s/%d/%s%s.replay", gS_ReplayFolder, style, gS_Map, (track > 0)? sTrack:"");
		DeleteFile(sPath);
		fWR = OpenFile(sPath, "wb");
	}

	if (saveCopy)
	{
		FormatEx(sPath, sPathLen, "%s/copy/%d_%d_%s.replay", gS_ReplayFolder, timestamp, steamid, gS_Map);
		DeleteFile(sPath);
		fCopy = OpenFile(sPath, "wb");
	}

	if (saveWR)
	{
		WriteReplayHeader(fWR, style, track, time, steamid, preframes, postframes, fZoneOffset, iSize);
	}

	if (saveCopy)
	{
		WriteReplayHeader(fCopy, style, track, time, steamid, preframes, postframes, fZoneOffset, iSize);
	}

	any aFrameData[sizeof(frame_t)];
	any aWriteData[sizeof(frame_t) * FRAMES_PER_WRITE];
	int iFramesWritten = 0;

	for(int i = 0; i < iSize; i++)
	{
		playerrecording.GetArray(i, aFrameData, sizeof(frame_t));

		for(int j = 0; j < sizeof(frame_t); j++)
		{
			aWriteData[(sizeof(frame_t) * iFramesWritten) + j] = aFrameData[j];
		}

		if(++iFramesWritten == FRAMES_PER_WRITE || i == iSize - 1)
		{
			if (saveWR)
			{
				fWR.Write(aWriteData, sizeof(frame_t) * iFramesWritten, 4);
			}

			if (saveCopy)
			{
				fCopy.Write(aWriteData, sizeof(frame_t) * iFramesWritten, 4);
			}

			iFramesWritten = 0;
		}
	}

	delete fWR;
	delete fCopy;

	if (!saveWR)
	{
		return;
	}
}

void WriteReplayHeader(File fFile, int style, int track, float time, int steamid, int preframes, int postframes, float fZoneOffset[2], int iSize)
{
	fFile.WriteLine("%d:" ... REPLAY_FORMAT_FINAL, REPLAY_FORMAT_SUBVERSION);

	fFile.WriteString(gS_Map, true);
	fFile.WriteInt8(style);
	fFile.WriteInt8(track);
	fFile.WriteInt32(preframes);

	fFile.WriteInt32(iSize - preframes - postframes);
	fFile.WriteInt32(view_as<int>(time));
	fFile.WriteInt32(steamid);

	fFile.WriteInt32(postframes);
	fFile.WriteInt32(view_as<int>(gF_Tickrate));

	fFile.WriteInt32(view_as<int>(fZoneOffset[0]));
	fFile.WriteInt32(view_as<int>(fZoneOffset[1]));
}

stock int LimitMoveVelFloat(float vel)
{
	int x = RoundToCeil(vel);
	return ((x < -666) ? -666 : ((x > 666) ? 666 : x)) & 0xFFFF;
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, int mouse[2])
{
	if (!gB_GrabbingPostFrames[client] || !(Shavit_ReplayEnabledStyle(style) && status == Timer_Running))
	{
		return Plugin_Continue;
	}

	if ((gI_PlayerFrames[client] / gF_Tickrate) > gCV_TimeLimit.FloatValue)
	{
		if (gI_HijackFrames[client])
		{
			gI_HijackFrames[client] = 0;
		}

		return Plugin_Continue;
	}

	float fTimescale = Shavit_GetClientTimescale(client);

	if (gF_NextFrameTime[client] > 0.0)
	{
		gF_NextFrameTime[client] -= fTimescale;
		return Plugin_Continue;
	}

	if (gA_PlayerFrames[client].Length <= gI_PlayerFrames[client])
	{
		// Add about two seconds worth of frames so we don't have to resize so often
		gA_PlayerFrames[client].Resize(gI_PlayerFrames[client] + (RoundToCeil(gF_Tickrate) * 2));
		//PrintToChat(client, "resizing %d -> %d", gI_PlayerFrames[client], gA_PlayerFrames[client].Length);
	}

	frame_t aFrame;
	GetClientAbsOrigin(client, aFrame.pos);

	if (!gI_HijackFrames[client])
	{
		float vecEyes[3];
		GetClientEyeAngles(client, vecEyes);
		aFrame.ang[0] = vecEyes[0];
		aFrame.ang[1] = vecEyes[1];
	}
	else
	{
		aFrame.ang = gF_HijackedAngles[client];
		--gI_HijackFrames[client];
	}

	aFrame.buttons = buttons;
	aFrame.flags = GetEntityFlags(client);
	aFrame.mt = GetEntityMoveType(client);

	aFrame.mousexy = (mouse[0] & 0xFFFF) | ((mouse[1] & 0xFFFF) << 16);
	aFrame.vel = LimitMoveVelFloat(vel[0]) | (LimitMoveVelFloat(vel[1]) << 16);

	gA_PlayerFrames[client].SetArray(gI_PlayerFrames[client]++, aFrame, sizeof(frame_t));

	gF_NextFrameTime[client] += (1.0 - fTimescale);

	return Plugin_Continue;
}

stock int LimitMoveVelFloat(float vel)
{
	int x = RoundToCeil(vel);
	return ((x < -666) ? -666 : ((x > 666) ? 666 : x)) & 0xFFFF;
}

public int Native_GetClientFrameCount(Handle handler, int numParams)
{
	return gI_PlayerFrames[GetNativeCell(1)];
}

public int Native_GetPlayerPreFrames(Handle handler, int numParams)
{
	return gI_PlayerPrerunFrames[GetNativeCell(1)];
}

public int Native_SetPlayerPreFrames(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int preframes = GetNativeCell(2);

	gI_PlayerPrerunFrames[client] = preframes;
}

public int Native_GetReplayData(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool cheapCloneHandle = view_as<bool>(GetNativeCell(2));
	Handle cloned = null;

	if(gA_PlayerFrames[client] != null)
	{
		ArrayList frames = cheapCloneHandle ? gA_PlayerFrames[client] : gA_PlayerFrames[client].Clone();
		frames.Resize(gI_PlayerFrames[client]);
		cloned = CloneHandle(frames, plugin); // set the calling plugin as the handle owner

		if (!cheapCloneHandle)
		{
			// Only hit for .Clone()'d handles. .Clone() != CloneHandle()
			CloseHandle(frames);
		}
	}

	return view_as<int>(cloned);
}

public int Native_SetReplayData(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	ArrayList data = view_as<ArrayList>(GetNativeCell(2));
	bool cheapCloneHandle = view_as<bool>(GetNativeCell(3));

	if (gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}

	if (cheapCloneHandle)
	{
		data = view_as<ArrayList>(CloneHandle(data));
	}
	else
	{
		data = data.Clone();
	}

	delete gA_PlayerFrames[client];
	gA_PlayerFrames[client] = data;
	gI_PlayerFrames[client] = data.Length;
}

public int Native_HijackAngles(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	gF_HijackedAngles[client][0] = view_as<float>(GetNativeCell(2));
	gF_HijackedAngles[client][1] = view_as<float>(GetNativeCell(3));
	gI_HijackFrames[client] = GetNativeCell(4);
}