class HRTriggerVolumeStart_V1 extends HRTriggerVolume_V1;

// Track finish trigger -- the HRTriggerVolumeFinish_V1 instance
// that completes this Start-Finish pair.
var(HRScoreboard) HRTriggerVolumeFinish_V1 TrackFinishTrigger;

simulated event Touch(Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal)
{
	Super.Touch(Other, OtherComp, HitLocation, HitNormal);

	if (ROVehicle(Other) != none)
	{
	}
}

DefaultProperties
{
    BrushColor=(R=199,G=21,B=133,A=255)
}
