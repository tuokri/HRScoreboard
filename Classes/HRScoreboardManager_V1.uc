// Helicopter Racing Scoreboard Manager.
class HRScoreboardManager_V1 extends Actor
    placeable;

struct DateTime_V1
{
    var int Year;
    var int Month;
    var int DayOfWeek;
    var int Day;
    var int Hour;
    var int Min;
    var int Sec;
    var int MSec;
};

// TODO: maybe just use RealTimeSeconds?
// TODO: think about other kind of stats to keep track of.
// - distance traveled?
// - average velocity?
// - damage taken?
struct RaceStats_V1
{
    var PlayerReplicationInfo RacePRI;
    var ROVehicle Vehicle;
    var float RaceStart;

    // TODO: is this even needed?
    // var DateTime_V1 RaceStart;
    // var DateTime_V1 RaceFinish;
};

// Level version number. Increase this number whenever the race
// track is changed to distinguish race scores recorded on different
// versions of the track.
var(HRScoreboard) int LevelVersion;

// The font to draw the HUD scoreboard with.
var(HRScoreboard) Font ScoreboardFont;

const MAX_REPLICATED = 255;
var RaceStats_V1 ReplicatedRaceStats[MAX_REPLICATED];
var byte ReplicatedRaceStatsCount;

var private array<RaceStats_V1> OngoingRaceStats;

// Just for debugging / developing.
var PlayerReplicationInfo DebugPRI;

replication
{
    if (bNetDirty && Role == ROLE_Authority)
        ReplicatedRaceStats, ReplicatedRaceStatsCount;
}

simulated event PostBeginPlay()
{
    local HRTriggerVolume_V1 HRTV;

    super.PostBeginPlay();

    switch (WorldInfo.NetMode)
    {
        case NM_DedicatedServer:
            SetTimer(1.0, True, 'TimerLoopDedicatedServer');
            break;
        case NM_Standalone:
            SetTimer(0.5, True, 'TimerLoopStandalone');
            break;
        case NM_Client:
            SetTimer(0.5, True, 'TimerLoopClient');
            break;
        default:
            `hrlog("ERROR:" @ WorldInfo.NetMode $ " is not supported");
    }

    if (Role != ROLE_Authority)
    {
        return;
    }

    ForEach AllActors(class'HRTriggerVolume_V1', HRTV)
    {
        `hrlog("setting ScoreboardManager for " $ HRTV);
        HRTV.ScoreboardManager = self;
    }
}

function PushRaceStats(ROPawn ROP, ROVehicle ROV)
{
    local PlayerReplicationInfo PRI;
    local RaceStats_V1 NewStats;
    local int Idx;

    if(ROP.PlayerReplicationInfo == None)
    {
        if (WorldInfo.NetMode == NM_Standalone)
        {
            if (DebugPRI == None)
            {
                DebugPRI = Spawn(WorldInfo.Game.PlayerReplicationInfoClass, self);
                DebugPRI.PlayerName = "EditorPlayer";
            }
            PRI = DebugPRI;
        }
        else
        {
            return;
        }
    }
    else
    {
        PRI = ROP.PlayerReplicationInfo;
    }

    `hrlog("ROP: " $ ROP $ " PRI: " $ PRI $ " ROV: " $ ROV);

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx != INDEX_NONE)
    {
        `hrlog("removing existing PRI: " $ PRI);
        OngoingRaceStats.Remove(Idx, 1);
    }

    NewStats.RacePRI = PRI;
    NewStats.Vehicle = ROV;
    NewStats.RaceStart = WorldInfo.RealTimeSeconds;

    /*
    GetSystemTime(
        NewStats.RaceStart.Year,
        NewStats.RaceStart.Month,
        NewStats.RaceStart.DayOfWeek,
        NewStats.RaceStart.Day,
        NewStats.RaceStart.Hour,
        NewStats.RaceStart.Min,
        NewStats.RaceStart.Sec,
        NewStats.RaceStart.MSec
    );
    `hrlog("RaceStart.Hour: " $ NewStats.RaceStart.Hour);
    `hrlog("RaceStart.Min : " $ NewStats.RaceStart.Min);
    `hrlog("RaceStart.Sec : " $ NewStats.RaceStart.Sec);
    `hrlog("RaceStart.MSec: " $ NewStats.RaceStart.MSec);
    */

    // TODO: push finished races to separate array.
    OngoingRaceStats.AddItem(NewStats);
    `hrlog("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

function PopRaceStats(ROPawn ROP, ROVehicle ROV)
{
    local int Idx;
    local float RaceFinish;
    local float RaceStart;
    local PlayerReplicationInfo PRI;

    // local RaceStats_V1 RaceStats;
    // local DateTime_V1 RaceStart;
    // local DateTime_V1 RaceFinish;

    if(ROP.PlayerReplicationInfo == None)
    {
        if (WorldInfo.NetMode == NM_Standalone && DebugPRI != None)
        {
            PRI = DebugPRI;
        }
        else
        {
            return;
        }
    }
    else
    {
        PRI = ROP.PlayerReplicationInfo;
    }

    RaceFinish = WorldInfo.RealTimeSeconds;

    `hrlog("ROP: " $ ROP $ " PRI: " $ PRI $ " ROV: " $ ROV);

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx == INDEX_NONE)
    {
        return;
    }

    /*
    GetSystemTime(
        RaceFinish.Year,
        RaceFinish.Month,
        RaceFinish.DayOfWeek,
        RaceFinish.Day,
        RaceFinish.Hour,
        RaceFinish.Min,
        RaceFinish.Sec,
        RaceFinish.MSec
    );
    `hrlog("RaceFinish.Hour: " $ RaceFinish.Hour);
    `hrlog("RaceFinish.Min : " $ RaceFinish.Min);
    `hrlog("RaceFinish.Sec : " $ RaceFinish.Sec);
    `hrlog("RaceFinish.MSec: " $ RaceFinish.MSec);
    */

    RaceStart = OngoingRaceStats[Idx].RaceStart;
    WorldInfo.Game.Broadcast(
        self,
        PRI.PlayerName @ "finished in"
            @ RaceTimeToString(RaceStart, RaceFinish)
            @ "with" @ OngoingRaceStats[Idx].Vehicle.Class,
        'Say'
    );

    if (OngoingRaceStats[Idx].Vehicle != ROV)
    {
        `hrlog("ERROR:" @ ROP @ PRI @ PRI.PlayerName
            @ "vehicle changed during race:" @ OngoingRaceStats[Idx].Vehicle @ "!=" @ ROV);
    }

    OngoingRaceStats.Remove(Idx, 1);
    `hrlog("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

final function string RaceTimeToString(float S, float F)
{
    local float TotalSecs;
    local int Hours;
    local int Mins;
    local int Secs;
    local int MSecs;

    TotalSecs = F - S;
    Hours = TotalSecs / 3600;
    Mins = (TotalSecs - (Hours * 3600)) / 60;
    Secs = TotalSecs - (Hours * 3600) - (Mins * 60);
    MSecs = Round((TotalSecs - int(TotalSecs)) * 1000000);

    return Hours $ ":" $ Mins $ ":" $ Secs $ "." $ MSecs;
}

/*
final function string RaceDateTimeToString(const out DateTime_V1 S, const out DateTime_V1 F)
{
    local float TotalSecs;
    local int Hours;
    local int Mins;
    local int Secs;
    local int MSecs;

    TotalSecs = ((F.Hour - S.Hour) * 3600)
        + ((F.Min - S.Min) * 60)
        + (F.Sec - S.Sec)
        + ((F.MSec - S.MSec) / 1000);

    Hours = TotalSecs / 3600;
    Mins = (TotalSecs - (Hours * 3600)) / 60;
    Secs = TotalSecs - (Hours * 3600) - (Mins * 60);
    MSecs = Round((TotalSecs - int(TotalSecs)) * 1000000);

    return Hours $ ":" $ Mins $ ":" $ Secs $ "." $ MSecs;
}
*/

simulated function UpdateRaceStatArrays()
{
    local int Idx;

    for (Idx = 0; Idx < OngoingRaceStats.Length; ++Idx)
    {
        ReplicatedRaceStats[Idx] = OngoingRaceStats[Idx];
    }
    ReplicatedRaceStatsCount = OngoingRaceStats.Length;

    `hrlog("ReplicatedRaceStatsCount:" @ ReplicatedRaceStatsCount);
}

simulated event PostRenderFor(PlayerController PC, Canvas Canvas, vector CameraPosition, vector CameraDir)
{
    local int Idx;

    `hrlog("PC:" @ PC @ "Canvas:" @ Canvas @ "CameraPosition:" @ CameraPosition @ "CameraDir:" @ CameraDir);

    Canvas.Font = ScoreboardFont;

    for (Idx = 0; Idx < ReplicatedRaceStatsCount; ++Idx)
    {
        Canvas.SetPos(Canvas.SizeX - ((Canvas.SizeX / 5) + 96), (Canvas.SizeY / 5));
        Canvas.DrawText(
            ReplicatedRaceStats[Idx].RacePRI.PlayerName
                @ WorldInfo.RealTimeSeconds - ReplicatedRaceStats[Idx].RaceStart,
            True
        );
    }

    super.PostRenderFor(PC, Canvas, CameraPosition, CameraDir);
}

simulated function DrawScoreboard()
{
    local ROPlayerController ROPC;
    // local int Idx;
    // local Canvas Canvas;

    ForEach LocalPlayerControllers(class'ROPlayerController', ROPC)
    {
        `hrlog("ROPC:" @ ROPC);

        if (ROPC != None && ROPC.myHUD != None)
        {
            ROPC.myHUD.AddPostRenderedActor(self);
        /*

            Canvas = ROPC.myHud.Canvas;
            for (Idx = 0; Idx < ReplicatedRaceStatsCount; ++Idx)
            {
                Canvas.SetPos(Canvas.SizeX - (Canvas.SizeX / 10), (Canvas.SizeY / 5));
                Canvas.DrawText(
                    ReplicatedRaceStats[Idx].RacePRI.PlayerName
                        @ WorldInfo.RealTimeSeconds - ReplicatedRaceStats[Idx].RaceStart,
                    True
                );
            }
        */
        }
    }
}

function TimerLoopDedicatedServer()
{
    UpdateRaceStatArrays();
}

simulated function TimerLoopStandalone()
{
    UpdateRaceStatArrays();
    DrawScoreboard();
}

simulated function TimerLoopClient()
{
    DrawScoreboard();
}

DefaultProperties
{
	Begin Object Class=SpriteComponent Name=Sprite
		Sprite=Texture2D'EditorResources.Corpse'
		HiddenGame=True
		AlwaysLoadOnClient=False
		AlwaysLoadOnServer=False
	End Object
	Components.Add(Sprite)

    RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=100
	bHidden=True
	bOnlyDirtyReplication=True
	bSkipActorPropertyReplication=True

    bPostRenderIfNotVisible=True
    ScoreboardFont=Font'VN_UI_Mega_Fonts.Font_VN_Mega_36'
}
