// Helicopter Racing Scoreboard Manager.
class HRScoreboardManager_V1 extends Actor
    placeable
    config(HRScoreboardManager_V1);

// Race stats base struct. All values replicated.
struct RaceStats_V1
{
    var PlayerReplicationInfo RacePRI;
    var ROVehicle Vehicle;
    var float RaceStart;
    var float RaceFinish;

    // Caching these here so they are still available after
    // the player disconnects or the vehicle is gone.
    var string PlayerName;
    var string VehicleClassName;
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

var private int MaxWaypoints;

// Increment whenever StoredRaceStats_V1 is updated.
const CURRENT_CONFIG_VERSION = 1;
// Internal config version.
var() private editconst config int ConfigVersion;

// Race stats stored in a config file.
struct StoredRaceStats_V1
{
    var string PlayerName;
    var string PlayerUniqueId;
    var string VehicleClass;
    var string LevelName;
    var int LevelVersion;
    var float TotalTimeSeconds;
    var string FinishTimeStamp;
};

// Sorted top score stats array in a config file. Not displayed in live scoreboard.
// Only stored in the config file for archive purposes. Config filename is
// 'ROHRScoreboardManager_V1.ini'.
var config array<StoredRaceStats_V1> StoredTopScoreRaceStats;

var(HRScoreboard) int MaxStoredTopScoreRaceStatsInConfigFile<ToolTip=Max number of race stats stored in the local config file.|ClampMin=1|ClampMax=1000>;

// Level version number. Increase this number whenever the race
// track is changed to distinguish between race scores recorded
// on different versions of the track.
var(HRScoreboard) int LevelVersion;

// The name scoreboard manager uses when posting chat messages.
var(HRScoreboard) string ChatName;

// The font to draw the HUD scoreboard with.
var(HRScoreboardHUD) Font ScoreboardFont;
// Scoreboard background texture. Stretched to fit.
var(HRScoreboardHUD) Texture2D ScoreboardBGTex;
// Scoreboard background border texture. Stretched to fit.
var(HRScoreboardHUD) Texture2D ScoreboardBGBorder;
// Scoreboard background texture tint;
var(HRScoreboardHUD) LinearColor ScoreboardBGTint;
// Scoreboard text color.
var(HRScoreboardHUD) Color ScoreboardTextColor;
// Scoreboard text render settings.
var(HRScoreboardHUD) FontRenderInfo ScoreboardFontRenderInfo;
// Used to determine max scoreboard width. Only change if you know what you are doing.
var(HRScoreboardHUD) private string SizeTestString;
// Max number of finished races to display in the HUD scoreboard.
var(HRScoreboardHUD) byte MaxFinishedRaces;

// Scoreboard backend server host. Only change if you know what you are doing.
// Default = todo.todo.com.
var(HRScoreboardBackend) private string BackendHost;
// Scoreboard backend server port. Only change if you know what you are doing.
// Default = 54231.
var(HRScoreboardBackend) private int BackendPort;
// Is connection to backend statistics server enabled?
// Only change if you know what you are doing. Default = True.
var(HRScoreboardBackend) private bool bBackendConnectionEnabled;
// Online scoreboard web application URL. Only change if you know what you are doing.
var(HRScoreboardBackend) private string WebAppAddress;

var(HRScoreboardBackend) private editconst HRTcpLink_V1 HRTcpLink;
var(HRScoreboardBackend) private editconst class<HRTcpLink_V1> HRTcpLinkClass;

var() private editconst class<HRChatRelay_V1> ChatRelayClass;
var() private editconst HRChatRelay_V1 ChatRelay;

const MAX_REPLICATED = 255;
var() private editconst RaceStats_V1 ReplicatedRaceStats[MAX_REPLICATED];
var() private editconst RaceStats_V1 ReplicatedFinishedRaces[MAX_REPLICATED];
var() private editconst byte ReplicatedRaceStatsCount;
var() private editconst byte ReplicatedFinishedRaceStatsCount;

// Ongoing races for this session. Displayed in HUD scoreboard.
var() private array<RaceStatsComplex_V1> OngoingRaceStats;
// Races finished during this session. Displayed in HUD scoreboard.
var() private array<RaceStatsComplex_V1> FinishedRaces;

// Minimum interval between race waypoint updates.
var() private editconst float MinWayPointUpdateIntervalSeconds;

// Just for debugging / developing.
var() private editconst PlayerReplicationInfo DebugPRI;

const HUEY_NAME = "Huey";
const COBRA_NAME = "Cobra";
const LOACH_NAME = "Loach";
const BUSHRANGER_NAME = "Bushranger";

// Cached HUD drawing variables.
var private int DrawIdx;
var private int BGHeight;
var private int BGWidth;
var private int DrawRegionTopLeftX;
var private int DrawRegionTopLeftY;
var private vector2d TextSize;
//                                 "CharacterTestNameString123 99999.99999 sec"
const SESSION_LEADERBOARD_HEADER = "----------- SESSION LEADERBOARD ----------";

replication
{
    if (bNetDirty && Role == ROLE_Authority)
        ReplicatedRaceStats, ReplicatedRaceStatsCount, ReplicatedFinishedRaces,
        ReplicatedFinishedRaceStatsCount;
}

simulated function SanityCheckConfig()
{
    local int Idx;
    local bool bStoredStatsModified;

    MaxStoredTopScoreRaceStatsInConfigFile = Clamp(MaxStoredTopScoreRaceStatsInConfigFile, 1, 1000);

    if (ConfigVersion != CURRENT_CONFIG_VERSION)
    {
        `hrwarn("config version changed" @ "(" $ ConfigVersion
            @ "->" @ CURRENT_CONFIG_VERSION $ ")" @ "-- wiping all stored stats!");
        ConfigVersion = CURRENT_CONFIG_VERSION;
        StoredTopScoreRaceStats.Length = 0;
        bStoredStatsModified = True;
    }

    for (Idx = 0; Idx < StoredTopScoreRaceStats.Length; ++Idx)
    {
        if (StoredTopScoreRaceStats[Idx].PlayerUniqueId == "" || StoredTopScoreRaceStats[Idx].PlayerName == ""
            || StoredTopScoreRaceStats[Idx].VehicleClass == "" || StoredTopScoreRaceStats[Idx].LevelName == ""
            || StoredTopScoreRaceStats[Idx].FinishTimeStamp == "")
        {
            StoredTopScoreRaceStats.Remove(Idx--, 1);
            bStoredStatsModified = True;
        }
    }

    if (bStoredStatsModified)
    {
        SaveConfig();
    }
}

simulated event PostBeginPlay()
{
    local HRTriggerVolume_V1 HRTV;

    `hrlog(self @ "initializing");

    super.PostBeginPlay();

    SanityCheckConfig();

    `hrdebug("WorldInfo.NetMode:" @ WorldInfo.NetMode);

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
            `hrwarn(WorldInfo.NetMode @ "is not tested");
            SetTimer(1.0, True, 'TimerLoopStandalone');
    }

    if (Role != ROLE_Authority)
    {
        return;
    }

    if (bBackendConnectionEnabled && HRTcpLink == None)
    {
        HRTcpLink = Spawn(HRTcpLinkClass, self);
        HRTcpLink.SetOwner(self);
        HRTcpLink.Configure(BackendHost, BackendPort);
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
    if (bBackendConnectionEnabled)
    {
        WorldInfo.Game.Broadcast(ChatRelay,
            "visit" @ WebAppAddress @ "to see the online scoreboard", 'Say');
    }

    if (ChatRelay != None)
    {
        ChatRelay.Destroy();
    }

    if (HRTcpLink != None)
    {
        HRTcpLink.CloseLink();
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

    `hrdebug("ROP: " $ ROP $ " PRI: " $ PRI $ " ROV: " $ ROV);

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx != INDEX_NONE)
    {
        `hrdebug("removing existing PRI: " $ PRI);
        OngoingRaceStats.Remove(Idx, 1);
    }

    NewStats.RacePRI = PRI;
    NewStats.Vehicle = ROV;
    NewStats.RaceStart = WorldInfo.RealTimeSeconds;
    NewStats.WayPoints.AddItem(ROV.Location);
    NewStats.LastWayPointUpdateTime = NewStats.RaceStart;
    NewStats.VehicleClassName = VehicleClassToString(ROV.Class);
    NewStats.PlayerName = PRI.PlayerName;

    OngoingRaceStats.AddItem(NewStats);
    // `hrdebug("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

function PopRaceStats(ROPawn ROP, ROVehicle ROV)
{
    local string Message;
    local int Idx;
    local float RaceFinish;
    local float RaceStart;
    local PlayerReplicationInfo PRI;

    if(ROP.PlayerReplicationInfo == None)
    {
        if (WorldInfo.NetMode == NM_Standalone && DebugPRI != None)
        {
            PRI = DebugPRI;
        }
        else
        {
            `hrerror("cannot pop race stats, PRI is null");
            return;
        }
    }
    else
    {
        PRI = ROP.PlayerReplicationInfo;
    }

    RaceFinish = WorldInfo.RealTimeSeconds;

    `hrdebug("ROP: " $ ROP $ " PRI: " $ PRI $ " ROV: " $ ROV);

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx == INDEX_NONE)
    {
        return;
    }

    RaceStart = OngoingRaceStats[Idx].RaceStart;
    OngoingRaceStats[Idx].RaceFinish = RaceFinish;

    Message = PRI.PlayerName @ "finished in"
        @ RaceTimeToString(RaceStart, RaceFinish)
        @ "with" @ VehicleClassToString(OngoingRaceStats[Idx].Vehicle.Class);
    `hrlog(class'OnlineSubsystem'.static.UniqueNetIdToString(PRI.UniqueId) @ Message);
    WorldInfo.Game.Broadcast(ChatRelay, Message, 'Say');

    if (OngoingRaceStats[Idx].Vehicle != ROV)
    {
        `hrerror(ROP @ PRI @ PRI.PlayerName
            @ "vehicle changed during race:" @ OngoingRaceStats[Idx].Vehicle @ "!=" @ ROV);
    }
    else
    {
        StoreFinishedRace(OngoingRaceStats[Idx]);
    }

    OngoingRaceStats.Remove(Idx, 1);
    // `hrdebug("OngoingRaceStats.Length: " $ OngoingRaceStats.Length);
}

// TODO: sorting long struct arrays is going to do a lot of copying.
//   The performance of this function should be monitored even if this
//   only gets called rarely when a player finishes the track.
function StoreFinishedRace(RaceStatsComplex_V1 RaceStats)
{
    local int Idx;

    if (RaceStats.RacePRI == None)
    {
        `hrerror("cannot store finished race, RacePRI is null");
        return;
    }

    `hrdebug("before sort: FinishedRaces.Length" @ FinishedRaces.Length);

    if (HRTcpLink != None && bBackendConnectionEnabled)
    {
        HRTcpLink.SendFinishedRaceStats(RaceStats);
    }

    FinishedRaces.AddItem(RaceStats);
    if (FinishedRaces.Length > 1)
    {
        FinishedRaces.Sort(SortDelegate_RaceStatsComplex_V1);
    }

    `hrdebug("after sort: FinishedRaces.Length" @ FinishedRaces.Length);
    if (FinishedRaces.Length > MaxFinishedRaces)
    {
        FinishedRaces.Length = MaxFinishedRaces;
    }

    Idx = StoredTopScoreRaceStats.Length;
    StoredTopScoreRaceStats.Length = Idx + 1;

    `hrdebug("Idx:" @ Idx);
    `hrdebug("StoredTopScoreRaceStats.Length:" @ StoredTopScoreRaceStats.Length);

    StoredTopScoreRaceStats[Idx].PlayerName = RaceStats.PlayerName;
    StoredTopScoreRaceStats[Idx].PlayerUniqueId = class'OnlineSubsystem'.static.UniqueNetIdToString(RaceStats.RacePRI.UniqueId);
    StoredTopScoreRaceStats[Idx].VehicleClass = RaceStats.VehicleClassName;
    StoredTopScoreRaceStats[Idx].LevelName = WorldInfo.GetMapName(True);
    StoredTopScoreRaceStats[Idx].LevelVersion = LevelVersion;
    StoredTopScoreRaceStats[Idx].TotalTimeSeconds = RaceStats.RaceFinish - RaceStats.RaceStart;
    StoredTopScoreRaceStats[Idx].FinishTimeStamp = TimeStamp();
    `hrdebug("StoredTopScoreRaceStats[Idx].PlayerName" @ StoredTopScoreRaceStats[Idx].PlayerName);
    `hrdebug("StoredTopScoreRaceStats[Idx].PlayerUniqueId" @ StoredTopScoreRaceStats[Idx].PlayerUniqueId);
    `hrdebug("StoredTopScoreRaceStats[Idx].VehicleClass" @ StoredTopScoreRaceStats[Idx].VehicleClass);
    `hrdebug("StoredTopScoreRaceStats[Idx].LevelName" @ StoredTopScoreRaceStats[Idx].LevelName);
    `hrdebug("StoredTopScoreRaceStats[Idx].LevelVersion" @ StoredTopScoreRaceStats[Idx].LevelVersion);
    `hrdebug("StoredTopScoreRaceStats[Idx].TotalTimeSeconds" @ StoredTopScoreRaceStats[Idx].TotalTimeSeconds);
    `hrdebug("StoredTopScoreRaceStats[Idx].FinishTimeStamp" @ StoredTopScoreRaceStats[Idx].FinishTimeStamp);

    `hrdebug("before sort: StoredTopScoreRaceStats.Length:" @ StoredTopScoreRaceStats.Length);
    if (StoredTopScoreRaceStats.Length > 1)
    {
        StoredTopScoreRaceStats.Sort(SortDelegate_StoredRaceStats_V1);
    }
    if (StoredTopScoreRaceStats.Length > MaxStoredTopScoreRaceStatsInConfigFile)
    {
        StoredTopScoreRaceStats.Length = MaxStoredTopScoreRaceStatsInConfigFile;
    }
    `hrdebug("after sort: StoredTopScoreRaceStats.Length:" @ StoredTopScoreRaceStats.Length);

    SaveConfig();
}

static function string VehicleClassToString(class<ROVehicle> VehicleClass)
{
    switch (VehicleClass)
    {
        case class'ROHeli_UH1H_Content':
            return HUEY_NAME;
        case class'ROHeli_OH6_Content':
            return LOACH_NAME;
        case class'ROHeli_AH1G_Content':
            return COBRA_NAME;
        case class'ROHeli_UH1H_Gunship_Content':
            return BUSHRANGER_NAME;
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

simulated function UpdateRaceStatArrays()
{
    local int Idx;
    local ROVehicle ROV;

    for (Idx = 0; Idx < OngoingRaceStats.Length; ++Idx)
    {
        ROV = OngoingRaceStats[Idx].Vehicle;
        `hrdebug("ROV:" @ ROV);
        if (ROV != None)
        {
            // TODO: need to set a grace period of sorts? In case a "dead" vehicle crosses the finish line?
            if(ROV.IsPendingKill() || ROV.bDeadVehicle)
            {
                // Store death location (or closest last known location);
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
                    if (OngoingRaceStats[Idx].WayPoints.Length <= MaxWaypoints)
                    {
                        OngoingRaceStats[Idx].WayPoints.AddItem(ROV.Location);
                        // TODO: better logic to decide which waypoints to drop if we are maxed out?
                    }
                }
            }

            ReplicatedRaceStats[Idx].RacePRI = OngoingRaceStats[Idx].RacePRI;
            ReplicatedRaceStats[Idx].Vehicle = OngoingRaceStats[Idx].Vehicle;
            ReplicatedRaceStats[Idx].RaceStart = OngoingRaceStats[Idx].RaceStart;
            ReplicatedRaceStats[Idx].PlayerName = OngoingRaceStats[Idx].PlayerName;
            ReplicatedRaceStats[Idx].VehicleClassName = OngoingRaceStats[Idx].VehicleClassName;
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
        ReplicatedFinishedRaces[Idx].PlayerName = FinishedRaces[Idx].PlayerName;
        ReplicatedFinishedRaces[Idx].VehicleClassName = FinishedRaces[Idx].VehicleClassName;
    }

    ReplicatedFinishedRaceStatsCount = FinishedRaces.Length;
}

simulated event PostRenderFor(PlayerController PC, Canvas Canvas, vector CameraPosition, vector CameraDir)
{
    // `hrdebug("PC:" @ PC @ "Canvas:" @ Canvas @ "CameraPosition:" @ CameraPosition @ "CameraDir:" @ CameraDir);

    if ((ReplicatedRaceStatsCount == 0) && (ReplicatedFinishedRaceStatsCount == 0))
    {
        return;
    }

    Canvas.Font = ScoreboardFont;
    Canvas.TextSize(SizeTestString, TextSize.X, TextSize.Y);
    BGHeight = (TextSize.Y * (ReplicatedRaceStatsCount + ReplicatedFinishedRaceStatsCount)) + 10;
    BGWidth = TextSize.X + 10;

    // 1 more row for separator.
    if (ReplicatedFinishedRaceStatsCount > 0)
    {
        BGHeight += TextSize.Y;
    }

    DrawRegionTopLeftX = Canvas.SizeX - ((Canvas.SizeX / 7) + BGWidth);
    DrawRegionTopLeftY = (Canvas.SizeY / 7);

    // TODO: breaks everything else.
    // Canvas.SetOrigin(DrawRegionTopLeftX, DrawRegionTopLeftY);
    // Canvas.SetClip(DrawRegionTopLeftX + BGWidth, DrawRegionTopLeftY + BGHeight);

    Canvas.SetPos(DrawRegionTopLeftX, DrawRegionTopLeftY);
    Canvas.DrawTileStretched(ScoreboardBGTex, BGWidth, BGHeight, 0, 0,
        ScoreboardBGTex.SizeX, ScoreboardBGTex.SizeY, ScoreboardBGTint, True, True);
    Canvas.DrawTileStretched(ScoreboardBGBorder, BGWidth, BGHeight, 0, 0,
        ScoreboardBGBorder.SizeX, ScoreboardBGBorder.SizeY, ScoreboardBGTint, True, True);

    Canvas.SetPos(Canvas.CurX + 5, Canvas.CurY + 5);
    Canvas.SetDrawColorStruct(ScoreboardTextColor);

    for (DrawIdx = 0; DrawIdx < ReplicatedRaceStatsCount; ++DrawIdx)
    {
        if ((ReplicatedRaceStats[DrawIdx].RacePRI != None) && (ReplicatedRaceStats[DrawIdx].Vehicle != None))
        {
            Canvas.DrawText(
                ReplicatedRaceStats[DrawIdx].PlayerName
                    @ (WorldInfo.RealTimeSeconds - ReplicatedRaceStats[DrawIdx].RaceStart)
                    @ "sec",
                True
            );
        }
    }

    if (ReplicatedFinishedRaceStatsCount > 0)
    {
        Canvas.DrawText(SESSION_LEADERBOARD_HEADER, True);
        for (DrawIdx = 0; DrawIdx < ReplicatedFinishedRaceStatsCount; ++DrawIdx)
        {
            Canvas.DrawText(
                DrawIdx $ "." @ ReplicatedFinishedRaces[DrawIdx].PlayerName
                    @ (ReplicatedFinishedRaces[DrawIdx].RaceFinish - ReplicatedFinishedRaces[DrawIdx].RaceStart)
                    @ "sec" @ ReplicatedFinishedRaces[DrawIdx].VehicleClassName,
                True
            );
        }
    }

    super.PostRenderFor(PC, Canvas, CameraPosition, CameraDir);
}

simulated function DrawScoreboard()
{
    local ROPlayerController ROPC;

    ROPC = ROPlayerController(GetALocalPlayerController());
    `hrdebug("ROPC:" @ ROPC);
    if (ROPC != None && ROPC.myHUD != None)
    {
        ROPC.myHUD.bShowOverlays = True;
        ROPC.myHUD.AddPostRenderedActor(self);
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
function int SortDelegate_StoredRaceStats_V1(StoredRaceStats_V1 A, StoredRaceStats_V1 B)
{
    return B.TotalTimeSeconds - A.TotalTimeSeconds;
}

// Ascending sort based on total race time.
function int SortDelegate_RaceStatsComplex_V1(RaceStatsComplex_V1 A, RaceStatsComplex_V1 B)
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
    ScoreboardTextColor=(R=255, G=255, B=245, A=255)
    ScoreboardFontRenderInfo=(bClipText=True, bEnableShadow=True)
    ScoreboardBGTex=Texture2D'VN_UI_Textures.HUD.GameMode.UI_GM_Bar_Fill'
    ScoreboardBGBorder=Texture2D'VN_UI_Textures.HUD.GameMode.UI_GM_Bar_Frame'
    ScoreboardBGTint=(R=0.5,G=0.5,B=0.6,A=0.6)

    ChatName="<<Scoreboard>>"

    BackendHost=`HRBACKEND_DEFAULT_HOST_V1
    BackendPort=`HRBACKEND_DEFAULT_PORT_V1
    WebAppAddress=`HRBACKEND_DEFAULT_WEBAPP_URL_V1
    bBackendConnectionEnabled=True

    SizeTestString="CharacterTestNameString123 99999.99999 sec"

    MinWayPointUpdateIntervalSeconds=5.0
    MaxFinishedRaces=32

    MaxStoredTopScoreRaceStatsInConfigFile=50

    ChatRelayClass=class'HRChatRelay_V1'
    HRTcpLinkClass=class'HRTcpLink_V1'

    MaxWaypoints=100
}
