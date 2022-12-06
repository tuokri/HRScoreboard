// Helicopter Racing Scoreboard Manager.
class HRScoreboardManager_V1 extends Actor
    placeable
    config(HRScoreboardManager_V1);

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

// Race stats base struct. All values replicated.
struct RaceStats_V1
{
    var PlayerReplicationInfo RacePRI;
    var ROVehicle Vehicle;
    var float RaceStart;
    var float RaceFinish;

    // TODO: is this even needed?
    // var DateTime_V1 RaceStart;
    // var DateTime_V1 RaceFinish;
};

// Non-replicated race statistics.
// TODO: think about other kind of stats to keep track of.
// - distance traveled?
// - average velocity?
// - damage taken?
struct RaceStatsComplex_V1 extends RaceStats_V1
{
    var array<vector> WayPoints;
    var float LastWayPointUpdateTime;
};

// Race stats stored in a config file.
struct StoredRaceStats_V1
{
    var string PlayerName;
    var string PlayerUniqueId;
    var string VehicleClass;
    var string LevelName;
    var int LevelVersion;
    var float TotalTimeSeconds;
    var DateTime_V1 FinishDateTime;
};

// Sorted top score stats array in a config file.
var config array<StoredRaceStats_V1> StoredTopScoreRaceStats;

var(HRScoreboard) int MaxStoredTopScoreRaceStatsInConfigFile<ToolTip=Max number of race stats stored in the config file.|ClampMin=1|ClampMax=1000>;

// Level version number. Increase this number whenever the race
// track is changed to distinguish between race scores recorded
// on different versions of the track.
var(HRScoreboard) int LevelVersion;

// The font to draw the HUD scoreboard with.
var(HRScoreboard) Font ScoreboardFont;
// Scoreboard background texture. Stretched to fit.
var(HRScoreboard) Texture2D ScoreboardBGTex;
// Scoreboard background border texture. Stretched to fit.
var(HRScoreboard) Texture2D ScoreboardBGBorder;
// Scoreboard background texture tint;
var(HRScoreboard) LinearColor ScoreboardBGTint;
// Scoreboard text color.
var(HRScoreboard) Color ScoreboardTextColor;
// Scoreboard text render settings.
var(HRScoreboard) FontRenderInfo ScoreboardFontRenderInfo;

// The name scoreboard manager uses when posting chat messages.
var(HRScoreboard) string ChatName;

// Scoreboard backend server host. Only change if you know what you are doing.
// Default = todo.todo.com.
var(HRScoreboard) string BackendHost;
// Scoreboard backend server port. Only change if you know what you are doing.
// Default = 54231.
var(HRScoreboard) int BackendPort;

// Max number of finished races to display in the HUD scoreboard.
var(HRScoreboard) byte MaxFinishedRaces;

// Used to determine max scoreboard width.
var() string SizeTestString;

var() private editconst class<HRChatRelay_V1> ChatRelayClass;
var() private editconst HRChatRelay_V1 ChatRelay;

const MAX_REPLICATED = 255;
var() RaceStats_V1 ReplicatedRaceStats[MAX_REPLICATED];
var() RaceStats_V1 ReplicatedFinishedRaces[MAX_REPLICATED];
var() byte ReplicatedRaceStatsCount;
var() byte ReplicatedFinishedRaceStatsCount;

// Ongoing races for this session.
var() private array<RaceStatsComplex_V1> OngoingRaceStats;
// Races finished during this session.
var() private array<RaceStatsComplex_V1> FinishedRaces;

// Minimum interval between race waypoint updates.
var() float MinWayPointUpdateIntervalSeconds;

// Just for debugging / developing.
var PlayerReplicationInfo DebugPRI;

replication
{
    if (bNetDirty && Role == ROLE_Authority)
        ReplicatedRaceStats, ReplicatedRaceStatsCount, ReplicatedFinishedRaces,
        ReplicatedFinishedRaceStatsCount;
}

simulated event PostBeginPlay()
{
    local HRTriggerVolume_V1 HRTV;

    super.PostBeginPlay();

    `hrlog("WorldInfo.NetMode:" @ WorldInfo.NetMode);

    switch (WorldInfo.NetMode)
    {
        case NM_DedicatedServer:
            SetTimer(1.0, True, 'TimerLoopDedicatedServer');
            break;
        case NM_Standalone:
            SetTimer(1.0, True, 'TimerLoopStandalone');
            break;
        case NM_Client:
            SetTimer(1.0, True, 'TimerLoopClient');
            break;
        default:
            `hrlog("ERROR:" @ WorldInfo.NetMode @ "is not supported");
    }

    if (Role != ROLE_Authority)
    {
        return;
    }

    if (ChatRelay == None)
    {
        ChatRelay = Spawn(ChatRelayClass, self);
    }

    ForEach AllActors(class'HRTriggerVolume_V1', HRTV)
    {
        `hrlog("setting ScoreboardManager for " $ HRTV);
        HRTV.ScoreboardManager = self;
    }
}

event Destroyed()
{
    if (ChatRelay != None)
    {
        ChatRelay.Destroy();
    }
    super.Destroyed();
}

function PushRaceStats(ROPawn ROP, ROVehicle ROV)
{
    local PlayerReplicationInfo PRI;
    local RaceStatsComplex_V1 NewStats;
    local int Idx;

    if(ROP.PlayerReplicationInfo == None)
    {
        if (WorldInfo.NetMode == NM_Standalone)
        {
            if (DebugPRI == None)
            {
                DebugPRI = Spawn(WorldInfo.Game.PlayerReplicationInfoClass, self);
                DebugPRI.PlayerName = WorldInfo.Game.DefaultPlayerName;
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
    NewStats.WayPoints.AddItem(ROV.Location);
    NewStats.LastWayPointUpdateTime = NewStats.RaceStart;

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

    OngoingRaceStats.AddItem(NewStats);
    // `hrlog("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);

    // TODO: not a good place for this. Can spam network.
    // ClientStartDrawHUD(ROP.Controller);
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
    OngoingRaceStats[Idx].RaceFinish = RaceFinish;

    WorldInfo.Game.Broadcast(
        ChatRelay,
        PRI.PlayerName @ "finished in"
            @ RaceTimeToString(RaceStart, RaceFinish)
            @ "with" @ VehicleClassToString(OngoingRaceStats[Idx].Vehicle.Class),
        'Say'
    );

    if (OngoingRaceStats[Idx].Vehicle != ROV)
    {
        `hrlog("ERROR:" @ ROP @ PRI @ PRI.PlayerName
            @ "vehicle changed during race:" @ OngoingRaceStats[Idx].Vehicle @ "!=" @ ROV);
    }
    else
    {
        StoreFinishedRace(OngoingRaceStats[Idx]);
    }

    OngoingRaceStats.Remove(Idx, 1);
    // `hrlog("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

function StoreFinishedRace(RaceStatsComplex_V1 RaceStats)
{
    local DateTime_V1 FinishDateTime;
    local int Idx;

    FinishedRaces[FinishedRaces.Length] = RaceStats;
    FinishedRaces.Sort(SortDelegate_RaceStatsComplex_V1);

    if (FinishedRaces.Length > MaxFinishedRaces)
    {
        FinishedRaces.Length = MaxFinishedRaces;
    }

    Idx = StoredTopScoreRaceStats.Length + 1;
    StoredTopScoreRaceStats.Length = Idx;

    StoredTopScoreRaceStats[Idx].PlayerName = RaceStats.RacePRI.PlayerName;
    StoredTopScoreRaceStats[Idx].PlayerUniqueId = class'OnlineSubsystem'.static.UniqueNetIdToString(RaceStats.RacePRI.UniqueId);
    StoredTopScoreRaceStats[Idx].VehicleClass = string(RaceStats.Vehicle.Class);
    StoredTopScoreRaceStats[Idx].LevelName = WorldInfo.GetMapName(True);
    StoredTopScoreRaceStats[Idx].LevelVersion = LevelVersion;
    StoredTopScoreRaceStats[Idx].TotalTimeSeconds = RaceStats.RaceFinish - RaceStats.RaceStart;
    GetSystemTime(
        FinishDateTime.Year,
        FinishDateTime.Month,
        FinishDateTime.DayOfWeek,
        FinishDateTime.Day,
        FinishDateTime.Hour,
        FinishDateTime.Min,
        FinishDateTime.Sec,
        FinishDateTime.MSec
    );
    StoredTopScoreRaceStats[Idx].FinishDateTime = FinishDateTime;

    StoredTopScoreRaceStats.Sort(SortDelegate_StoredRaceStats_V1);

    if (StoredTopScoreRaceStats.Length > MaxStoredTopScoreRaceStatsInConfigFile)
    {
        StoredTopScoreRaceStats.Length = MaxStoredTopScoreRaceStatsInConfigFile;
    }

    SaveConfig();
}

static function string VehicleClassToString(class<ROVehicle> VehicleClass)
{
    switch (VehicleClass)
    {
        case class'ROHeli_UH1H_Content':
            return "Huey";
        case class'ROHeli_OH6_Content':
            return "Loach";
        case class'ROHeli_AH1G_Content':
            return "Cobra";
        case class'ROHeli_UH1H_Gunship_Content':
            return "Bushranger";
        default:
            return string(VehicleClass);
    }
}

static function string RaceTimeToString(float S, float F)
{
    local float TotalSecs;
    local string TimeString;
    local int Hours;
    local int Mins;
    local int Secs;
    local int MSecs;

    TotalSecs = F - S;
    Hours = TotalSecs / 3600;
    Mins = (TotalSecs - (Hours * 3600)) / 60;
    Secs = TotalSecs - (Hours * 3600) - (Mins * 60);
    MSecs = Round((TotalSecs - int(TotalSecs)) * 1000000);

    if (Hours < 10)
    {
        TimeString $= "0";
    }
    TimeString $= Hours $ ":";
    if (Mins < 10)
    {
        TimeString $= "0";
    }
    TimeString $= Mins $ ":";
    if (Secs < 10)
    {
        TimeString $= "0";
    }
    TimeString $= Secs $ ".";
    TimeString $= MSecs;

    return TimeString;
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
    local ROVehicle ROV;

    for (Idx = 0; Idx < OngoingRaceStats.Length; ++Idx)
    {
        ROV = OngoingRaceStats[Idx].Vehicle;
        `hrlog("ROV:" @ ROV);
        if (ROV != None)
        {
            // TODO: need to set a grace period of sorts? In case a "dead" vehicle crosses the finish line?
            if(ROV.IsPendingKill() || ROV.bDeadVehicle)
            {
                OngoingRaceStats[Idx].LastWayPointUpdateTime = WorldInfo.RealTimeSeconds;
                OngoingRaceStats[Idx].WayPoints.AddItem(ROV.Location);
                OngoingRaceStats[Idx].Vehicle = None;
            }
            else
            {
                if (WorldInfo.RealTimeSeconds >= (
                    OngoingRaceStats[Idx].LastWayPointUpdateTime + MinWayPointUpdateIntervalSeconds))
                {
                    OngoingRaceStats[Idx].LastWayPointUpdateTime = WorldInfo.RealTimeSeconds;
                    OngoingRaceStats[Idx].WayPoints.AddItem(ROV.Location);
                }
            }

            ReplicatedRaceStats[Idx].RacePRI = OngoingRaceStats[Idx].RacePRI;
            ReplicatedRaceStats[Idx].Vehicle = OngoingRaceStats[Idx].Vehicle;
            ReplicatedRaceStats[Idx].RaceStart = OngoingRaceStats[Idx].RaceStart;
        }
        else
        {
            OngoingRaceStats.Remove(Idx--, 1);
        }
    }

    ReplicatedRaceStatsCount = OngoingRaceStats.Length;

    // TODO: Needless copies? Better way to do this?
    for (Idx = 0; Idx < FinishedRaces.Length; ++Idx)
    {
        ReplicatedFinishedRaces[Idx].RacePRI = FinishedRaces[Idx].RacePRI;
        ReplicatedFinishedRaces[Idx].Vehicle = FinishedRaces[Idx].Vehicle;
        ReplicatedFinishedRaces[Idx].RaceStart = FinishedRaces[Idx].RaceStart;
        ReplicatedFinishedRaces[Idx].RaceFinish = FinishedRaces[Idx].RaceFinish;
    }

    ReplicatedFinishedRaceStatsCount = FinishedRaces.Length;
}

simulated event PostRenderFor(PlayerController PC, Canvas Canvas, vector CameraPosition, vector CameraDir)
{
    local int Idx;
    local int BGHeight;
    local int BGWidth;
    local vector2d TextSize;

    // `hrlog("PC:" @ PC @ "Canvas:" @ Canvas @ "CameraPosition:" @ CameraPosition @ "CameraDir:" @ CameraDir);

    if ((ReplicatedRaceStatsCount == 0) && (ReplicatedFinishedRaceStatsCount == 0))
    {
        return;
    }


    Canvas.Font = ScoreboardFont;
    Canvas.TextSize(SizeTestString, TextSize.X, TextSize.Y);
    BGHeight = (TextSize.Y * (ReplicatedRaceStatsCount + ReplicatedFinishedRaceStatsCount)) + 10;
    BGWidth = TextSize.X + 5;

    // 1 more row for separator.
    if (ReplicatedFinishedRaceStatsCount > 0)
    {
        BGHeight += TextSize.Y;
    }

    Canvas.SetPos(Canvas.SizeX - ((Canvas.SizeX / 6) + BGWidth), (Canvas.SizeY / 6));
    Canvas.DrawTileStretched(ScoreboardBGTex, BGWidth, BGHeight, 0, 0, BGWidth, BGHeight, ScoreboardBGTint);
    Canvas.DrawTileStretched(ScoreboardBGBorder, BGWidth, BGHeight, 0, 0, BGWidth, BGHeight, ScoreboardBGTint);

    Canvas.SetPos(Canvas.CurX + 5, Canvas.CurY + 5);
    Canvas.SetDrawColorStruct(ScoreboardTextColor);

    for (Idx = 0; Idx < ReplicatedRaceStatsCount; ++Idx)
    {
        if ((ReplicatedRaceStats[Idx].RacePRI != None) && (ReplicatedRaceStats[Idx].Vehicle != None))
        {
            Canvas.DrawText(
                ReplicatedRaceStats[Idx].RacePRI.PlayerName
                    @ WorldInfo.RealTimeSeconds - ReplicatedRaceStats[Idx].RaceStart,
                True
            );
        }
    }

    if (ReplicatedFinishedRaceStatsCount > 0)
    {
        //              "CharacterTestNameString123 99999.99999"
        Canvas.DrawText("--------- SESSION LEADERBOARD --------", True);
        for (Idx = 0; Idx < ReplicatedFinishedRaceStatsCount; ++Idx)
        {
            Canvas.DrawText(
                Idx $ "." @ ReplicatedFinishedRaces[Idx].RacePRI.PlayerName
                    @ ReplicatedFinishedRaces[Idx].RaceFinish - ReplicatedFinishedRaces[Idx].RaceStart,
                True
            );
        }
    }

    super.PostRenderFor(PC, Canvas, CameraPosition, CameraDir);
}

/*
reliable client function ClientStartDrawHUD(Controller C)
{
    local PlayerController PC;

    `hrlog("C:" @ C);

    PC = PlayerController(C);
    if (PC != None && PC.myHUD != None)
    {
        PC.myHUD.bShowOverlays = True;
        PC.myHUD.AddPostRenderedActor(self);
    }
}
*/

simulated function DrawScoreboard()
{
    local ROPlayerController ROPC;

    ForEach LocalPlayerControllers(class'ROPlayerController', ROPC)
    {
        // `hrlog("ROPC:" @ ROPC);

        if (ROPC != None && ROPC.myHUD != None)
        {
            ROPC.myHUD.bShowOverlays = True;
            ROPC.myHUD.AddPostRenderedActor(self);
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
    // TODO: is there a better way to do this than check with a timer?
    DrawScoreboard();
}

simulated function TimerLoopClient()
{
    // TODO: is there a better way to do this than check with a timer?
    DrawScoreboard();
}

// Ascending sort based on total race time.
function int SortDelegate_StoredRaceStats_V1(const out StoredRaceStats_V1 A, const out StoredRaceStats_V1 B)
{
    return B.TotalTimeSeconds - A.TotalTimeSeconds;
}

// Ascending sort based on total race time.
function int SortDelegate_RaceStatsComplex_V1(const out RaceStatsComplex_V1 A, const out RaceStatsComplex_V1 B)
{
    return (B.RaceFinish - B.RaceStart) - (A.RaceFinish - A.RaceStart);
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
    bAlwaysRelevant=True
	bSkipActorPropertyReplication=True
    bPostRenderIfNotVisible=True

    ScoreboardFont=Font'EngineFonts.SmallFont'
    ScoreboardTextColor=(R=255, G=255, B=255, A=255)
    ScoreboardFontRenderInfo=(bClipText=True, bEnableShadow=True)
    ScoreboardBGTex=Texture2D'VN_UI_Textures.HUD.GameMode.UI_GM_Bar_Fill'
    ScoreboardBGBorder=Texture2D'VN_UI_Textures.HUD.GameMode.UI_GM_Bar_Frame'
    ScoreboardBGTint=(R=0.5, G=0.5, B=0.5, A=0.5)

    ChatName="<<Scoreboard>>"

    BackendHost=""
    BackendPort=54231

    SizeTestString="CharacterTestNameString123 99999.99999"

    MinWayPointUpdateIntervalSeconds=5.0
    MaxFinishedRaces=32

    MaxStoredTopScoreRaceStatsInConfigFile=250

    ChatRelayClass=class'HRChatRelay_V1'
}
