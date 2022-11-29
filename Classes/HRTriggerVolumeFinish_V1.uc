class HRTriggerVolumeFinish_V1 extends HRTriggerVolume_V1;

simulated event Touch(Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal)
{
	Super.Touch(Other, OtherComp, HitLocation, HitNormal);

	if (ROVehicle(Other) != none)
	{
	}
}

DefaultProperties
{
    BrushColor=(R=152,G=251,B=152,A=255)
}
