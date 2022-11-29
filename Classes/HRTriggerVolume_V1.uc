class HRTriggerVolume_V1 extends ROTriggerVolume
    abstract;

// HRScoreboardManager_V1 instance that keeps track of race statistics.
// Assigned dynamically to each volume when the game begins.
var HRScoreboardManager_V1 ScoreboardManager;

DefaultProperties
{
    bPawnsOnly=True
    bProjTarget=False
}
