class HRTcpLink_V1 extends TcpLink;

`define HR_PROTO_VERSION 1

struct HRPacket_V1
{
    var byte Size;
    var byte ProtocolVersion;
};

// Net protocol version. Update when packet binary format changes.
var() private editconst byte ProtocolVersion;

var() private editconst string BackendHost;
var() private editconst int BackendPort;

var private bool bConfigured;

// Max number of packets queued for sending to backend.
var private int MaxSendQueueLength;
var private array<HRPacket_V1> SendQueue;
// Whether to keep retrying failed connection attempt or not.
var private bool bRetryOnFail;

final function Configure(string ServerHost, int ServerPort)
{
    BackendHost = ServerHost;
    BackendPort = ServerPort;

    bRetryOnFail = True;
    bConfigured = True;

    Owner.SetTimer(2.0, False, 'CheckResolveStatus');

    ResolveBackend();
}

final function CheckResolveStatus()
{
    if (!IsConnected())
    {
        Close();
    }
    if (bRetryOnFail)
    {
        ResolveBackend();
    }
}

final function ResolveBackend()
{
    `hrlog("attempting to resolve:" @ BackendHost);
    Resolve(BackendHost);
}

final function CloseLink()
{
    Close();
}

event Resolved(IpAddr Addr)
{
    `hrlog(BackendHost @ "resolved to:" @ IpAddrToString(Addr));
}

event ResolveFailed()
{
    `hrlog(self @ "failed to resolve host");
    if (bRetryOnFail)
    {
        SetTimer(2.0, False, 'ResolveBackend');
    }
}

event Opened()
{
}

event Closed()
{
    `hrlog(self @ "closed connection");
}

event Tick(float DeltaTime)
{
    super.Tick(DeltaTime);

    if (bConfigured && IsConnected())
    {
        PerformIO();
    }
}

final function PerformIO()
{

}

DefaultProperties
{
    TickGroup=TG_DuringAsyncWork
    LinkMode=MODE_Binary
    ProtocolVersion=`HR_PROTO_VERSION
    MaxSendQueueLength=1000
    bRetryOnFail=True
}
