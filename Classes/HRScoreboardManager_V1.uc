class HRScoreboardManager_V1 extends Info;

struct DateTime_V1
{
    var int Year;
    var int Month;
    var int DayOfWeek;
    var int Day;
    var int Hour;
    var int Min;
    var int Sec;
    var int MSec;
};

struct RaceStats_V1
{
    var PlayerReplicationInfo RacePRI;
    var DateTime_V1 RaceStart;
    // TODO: is this even needed?
    // var DateTime_V1 RaceFinish;
};

var private array<RaceStats_V1> OngoingRaceStats;

event PostBeginPlay()
{
    local HRTriggerVolume_V1 HRTV;

    super.PostBeginPlay();

    ForEach AllActors(class'HRTriggerVolume_V1', HRTV)
    {
        HRTV.ScoreboardManager = self;
    }
}

// TODO: need to also store vehicle type.
function PushRaceStats(PlayerReplicationInfo PRI)
{
    local RaceStats_V1 NewStats;
    local int Idx;

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx != INDEX_NONE)
    {
        OngoingRaceStats.Remove(Idx, 1);
    }

    NewStats.RacePRI = PRI;
    GetSystemTime(
        NewStats.RaceStart.Year,
        NewStats.RaceStart.Month,
        NewStats.RaceStart.DayOfWeek,
        NewStats.RaceStart.Day,
        NewStats.RaceStart.Hour,
        NewStats.RaceStart.Min,
        NewStats.RaceStart.Sec,
        NewStats.RaceStart.MSec
    );

    OngoingRaceStats.AddItem(NewStats);
}

function PopRaceStats(PlayerReplicationInfo PRI)
{
    local int Idx;
    local DateTime_V1 RaceFinish;

    Idx = OngoingRaceStats.Find('RacePRI', PRI);
    if (Idx != INDEX_NONE)
    {
        GetSystemTime(
            RaceFinish.Year,
            RaceFinish.Month,
            RaceFinish.DayOfWeek,
            RaceFinish.Day,
            RaceFinish.Hour,
            RaceFinish.Min,
            RaceFinish.Sec,
            RaceFinish.MSec
        );
    }

    // TODO: Handle successfully finished race.
}

DefaultProperties
{
    NetUpdateFrequency=100
}
