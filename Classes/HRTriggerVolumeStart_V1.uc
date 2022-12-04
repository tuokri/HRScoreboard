// Triggers race start for touching actor.
class HRTriggerVolumeStart_V1 extends HRTriggerVolume_V1;

// Track finish trigger -- the HRTriggerVolumeFinish_V1 instance
// that completes this Start-Finish pair.
var(HRScoreboard) HRTriggerVolumeFinish_V1 TrackFinishTrigger;

simulated event Touch(Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal)
{
    local ROPawn ROP;
    local ROVehicle ROV;

    // `hrlog("Other: " $ Other);

    Super.Touch(Other, OtherComp, HitLocation, HitNormal);

    if (Role != ROLE_Authority || TrackFinishTrigger == None)
    {
        // `hrlog("Role:" @ Role);
        // `hrlog("TrackFinishTrigger:" @ TrackFinishTrigger);
        return;
    }

    ROV = ROVehicle(Other);
    // `hrlog("ROV:" @ ROV);
    if (ROV != none)
    {
        ROP = ROV.GetDriverForSeatIndex(0);
    }

    if (ROP != None)
    {
        if (ScoreboardManager != None)
        {
            ScoreboardManager.PushRaceStats(ROP, ROV);
        }
    }
}

DefaultProperties
{
    BrushColor=(R=100,G=21,B=133,A=255)
}
