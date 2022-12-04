// Triggers end of race for touching actor.
class HRTriggerVolumeFinish_V1 extends HRTriggerVolume_V1;

simulated event Touch(Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal)
{
    local ROPawn ROP;
    local ROVehicle ROV;

    // `hrlog("Other: " $ Other);

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
        if (ScoreboardManager != None)
        {
            ScoreboardManager.PopRaceStats(ROP);
        }
    }
}

DefaultProperties
{
    BrushColor=(R=149,G=255,B=143,A=255)
}
