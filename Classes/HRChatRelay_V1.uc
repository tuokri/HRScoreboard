class HRChatRelay_V1 extends Controller;

simulated event PostBeginPlay()
{
    super.PostBeginPlay();
    InitPlayerReplicationInfo();
}

function InitPlayerReplicationInfo()
{
    PlayerReplicationInfo = Spawn(WorldInfo.Game.PlayerReplicationInfoClass, self);
    PlayerReplicationInfo.bIsInactive = True;
    PlayerReplicationInfo.PlayerName = class'HRScoreboardManager_V1'.default.ChatName;
    PlayerReplicationInfo.bIsSpectator = True;
    PlayerReplicationInfo.bOnlySpectator = True;
    PlayerReplicationInfo.bOutOfLives = True;
    PlayerReplicationInfo.bWaitingPlayer = False;
}

event PlayerTick( float DeltaTime )
{
    // This is needed because PlayerControllers with no actual player attached
    // will leak during seamless traveling.
    if (WorldInfo.NextURL != "" || WorldInfo.IsInSeamlessTravel())
    {
        `hrdebug(self @ "destroying self due to seamless travel");
        Destroy();
    }
}

// `ifdef(HRDEBUG)
// simulated exec function SendBackendDebugMessage()
// {
//     local RaceStatsComplex_V1 RaceStats;
//     local ROVehicle ROV;
//     local HRTcpLink_V1 Link;

//     `hrdebug("sending TCP test message");

//     ForEach AllActors(class'ROVehicle', ROV)
//     {
//         break;
//     }

//     RaceStats.RacePRI = GetALocalPlayerController().PlayerReplicationInfo;
//     RaceStats.Vehicle = ROV;
//     RaceStats.RaceStart = FRand() * Rand(100);
//     RaceStats.RaceFinish = RaceStats.RaceStart + WorldInfo.RealTimeSeconds;
//     RaceStats.PlayerName = "TestPlayer";
//     RaceStats.VehicleClassName = "Loach";

//     ForEach AllActors(class'HRTcpLink_V1', Link)
//     {
//         Link.SendFinishedRaceStats(RaceStats);
//     }
// }
// `endif

DefaultProperties
{
    bIsPlayer=False
    bAlwaysTick=True
}
