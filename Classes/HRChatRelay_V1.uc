class HRChatRelay_V1 extends Controller;

function InitPlayerReplicationInfo()
{
    PlayerReplicationInfo = Spawn(WorldInfo.Game.PlayerReplicationInfoClass, self,, vect(0,0,0), rot(0,0,0));
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
