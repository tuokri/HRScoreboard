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

DefaultProperties
{
    bIsPlayer=False
    bAlwaysTick=True
}
