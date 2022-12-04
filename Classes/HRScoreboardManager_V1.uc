// Helicopter Racing Scoreboard Manager.
class HRScoreboardManager_V1 extends Info
    placeable;

// Level version number. Increase this number whenever the race
// track is changed to distinguish race scores recorded on different
// versions of the track.
var(HRScoreboard) int LevelVersion;

// Just for debugging / developing.
var PlayerReplicationInfo DebugPRI;

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

// TODO: think about other kind of stats to keep track of.
// - distance traveled?
// - average velocity?
// - damage taken?
struct RaceStats_V1
{
    var PlayerReplicationInfo RacePRI;
    var class<ROVehicle> VehicleClass;
    var DateTime_V1 RaceStart;
    // TODO: is this even needed?
    // var DateTime_V1 RaceFinish;
};

var private array<RaceStats_V1> OngoingRaceStats;

event PostBeginPlay()
{
    local HRTriggerVolume_V1 HRTV;

    super.PostBeginPlay();

    ForEach AllActors(class'HRTriggerVolume_V1', HRTV)
    {
        `hrlog("setting ScoreboardManager for " $ HRTV);
        HRTV.ScoreboardManager = self;
    }
}

// TODO: need to also store vehicle type and something else?
function PushRaceStats(ROPawn ROP, ROVehicle ROV)
{
    local PlayerReplicationInfo PRI;
    local RaceStats_V1 NewStats;
    local int Idx;

    if(ROP.PlayerReplicationInfo == None)
    {
        if (class'Engine'.static.IsEditor() || WorldInfo.NetMode == NM_Standalone)
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
    NewStats.VehicleClass = ROV.Class;

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

    OngoingRaceStats.AddItem(NewStats);
    `hrlog("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

function PopRaceStats(ROPawn ROP)
{
    local int Idx;
    local PlayerReplicationInfo PRI;
    local DateTime_V1 RaceFinish;
    local RaceStats_V1 RaceStats;

    if(ROP.PlayerReplicationInfo == None)
    {
        if ((class'Engine'.static.IsEditor() || WorldInfo.NetMode == NM_Standalone) && DebugPRI != None)
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

    `hrlog("ROP: " $ ROP $ " PRI: " $ PRI);

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx == INDEX_NONE)
    {
        return;
    }

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

    RaceStats = OngoingRaceStats[Idx];

    // TODO: Handle successfully finished race.
    `hrlog("RaceFinish.Hour: " $ RaceFinish.Hour);
    `hrlog("RaceFinish.Min : " $ RaceFinish.Min);
    `hrlog("RaceFinish.Sec : " $ RaceFinish.Sec);
    `hrlog("RaceFinish.MSec: " $ RaceFinish.MSec);

    WorldInfo.Game.Broadcast(
        self,
        PRI.PlayerName @ "finished in"
            @ RaceTimeToString(RaceStats.RaceStart, RaceFinish)
            @ "with" @ RaceStats.VehicleClass,
        'Say'
    );

    OngoingRaceStats.Remove(Idx, 1);
    `hrlog("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

function string RaceTimeToString(const out DateTime_V1 S, const out DateTime_V1 F)
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
    MSecs = Round((TotalSecs - int(TotalSecs)) * 1000);

    return Hours $ ":" $ Mins $ ":" $ Secs $ "." $ MSecs;
}

DefaultProperties
{
    LevelVersion=0
    NetUpdateFrequency=100

    Begin Object NAME=Sprite
        Sprite=Texture2D'EditorResources.Corpse'
        Scale=2.0
    End Object
}
