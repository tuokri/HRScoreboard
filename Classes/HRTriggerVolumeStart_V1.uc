class HRTriggerVolumeStart_V1 extends HRTriggerVolume_V1;

// Track finish trigger -- the HRTriggerVolumeFinish_V1 instance
// that completes this Start-Finish pair.
var(HRScoreboard) HRTriggerVolumeFinish_V1 TrackFinishTrigger;

simulated event Touch(Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal)
{
	local ROPawn ROP;
    local ROVehicle ROV;

    Super.Touch(Other, OtherComp, HitLocation, HitNormal);

    if (Role != ROLE_Authority)
    {
        return;
    }

    ROV = ROVehicle(Other);
	if (ROV != none)
	{
        ROP = ROV.GetDriverForSeatIndex(0);
	}

    if (ROP != None)
    {
        if(ROP.PlayerReplicationInfo != None)
        {
            ScoreboardManager.PushRaceStats(ROP.PlayerReplicationInfo);
        }
    }
}

DefaultProperties
{
    BrushColor=(R=199,G=21,B=133,A=255)
}
