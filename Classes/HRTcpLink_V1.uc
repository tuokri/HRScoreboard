class HRTcpLink_V1 extends TcpLink;

`define HR_PROTO_VERSION 1

var private int XXTEAKey[4];
`define MX (((Z>>5^Y<<2) + (Y>>3^Z<<4)) ^ ((Sum^Y) + (XXTEAKey[(P&3)^E] ^ Z)))
// const DELTA = 0x9e3779b9;
const DELTA = 0x243f6a88;

enum EPacketID
{
    EPID_Reserved,
    EPID_FinishedRaceStats,
};

const HEADER_BYTES = 3;
struct HRPacket_V1
{
    var byte Size;
    var byte ProtocolVersion;
    var byte PacketID;

    // Integers for XXTEA. Sent as bytes. Max 248 bytes.
    var int Data[31];
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
var private byte RetryCount;

var private byte SendBuffer[255];
var private byte SendBufferSize;
var private int DataBuffer[31];
var private int DataBufferSize;

final function SendFinishedRaceStats(const out RaceStatsComplex_V1 RaceStats)
{
    local HRPacket_V1 Packet;
    local float Test;

    if (SendQueue.Length >= MaxSendQueueLength)
    {
        `hrerror("MaxSendQueueLength reached, dropping packet");
    }

    Packet.Size = 19;
    Packet.ProtocolVersion = ProtocolVersion;
    Packet.PacketID = EPID_FinishedRaceStats;

    Packet.Data[0] = RaceStats.RacePRI.UniqueId.Uid.A;
    Packet.Data[1] = RaceStats.RacePRI.UniqueId.Uid.B;
    `hrlog("RaceStats.RaceFinish:" @ RaceStats.RaceFinish);
    Packet.Data[2] = (
          ((RaceStats.RaceFinish >> 24) & 0xff)
        | ((RaceStats.RaceFinish >> 16) & 0xff)
        | ((RaceStats.RaceFinish >>  8) & 0xff)
        | ((RaceStats.RaceFinish      ) & 0xff)
    );
    Test = (
          ((RaceStats.RaceFinish >> 24) & 0xff)
        | ((RaceStats.RaceFinish >> 16) & 0xff)
        | ((RaceStats.RaceFinish >>  8) & 0xff)
        | ((RaceStats.RaceFinish      ) & 0xff)
    );
    `hrlog("Test:" @ Test);
    `hrlog("Packet.Data[2]:" @ Packet.Data[2]);
    Packet.Data[3] = 0x4040404; // PKCS#7.

    // - vehicle class/name
    // - player name (for epic users only)
    // - total time
    // - level version
    // - level name
    // - waypoints? (limit count?)

    // date and time generated on backend server

    SendQueue.AddItem(Packet);
}

final private function UniqueNetIdToBytes(const out UniqueNetId UniqueId,
    out byte Buffer[255], optional byte StartIndex = 0)
{
    Buffer[StartIndex++] = (UniqueId.Uid.A      ) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.A >> 8 ) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.A >> 16) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.A >> 24) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.B      ) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.B >> 8 ) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.B >> 16) & 0xff;
    Buffer[StartIndex++] = (UniqueId.Uid.B >> 24) & 0xff;
}

final function Configure(string ServerHost, int ServerPort)
{
    BackendHost = ServerHost;
    BackendPort = ServerPort;

    bRetryOnFail = True;
    bConfigured = True;

    RetryCount = 0;

    SetTimer(GetTimeout(), False, 'CheckResolveStatus');

    ResolveBackend();
}

final private function float GetTimeout()
{
    return FClamp(2.0 + (RetryCount / 10), 2.0, 4.0);
}

final private function float GetRetryDelay()
{
    return FClamp(2.0 ** RetryCount, 2.0, 16.0);
}

final private function CheckResolveStatus()
{
    if (!IsConnected())
    {
        Close();
    }
    Retry();
}

final private function ResolveBackend()
{
    `hrlog("attempting to resolve:" @ BackendHost);
    Resolve(BackendHost);
}

final private function Retry()
{
    local int Error;

    if (bRetryOnFail)
    {
        Error = GetLastError();
        if (Error != 0)
        {
            `hrlog("last WinSock error was:" @ WinSockErrorToString(Error));
        }
        ++RetryCount;
        SetTimer(GetRetryDelay() + GetTimeout(), False, 'CheckResolveStatus');
        SetTimer(GetRetryDelay(), False, 'ResolveBackend');
    }
}

final function CloseLink()
{
    bRetryOnFail = False;
    Close();
}

event Resolved(IpAddr Addr)
{
    `hrlog(BackendHost @ "resolved to:" @ IpAddrToString(Addr));

    Addr.Port = BackendPort;
    BindPort();

    `hrlog("attempting to open connection to:" @ IpAddrToString(Addr));
    if (!Open(Addr))
    {
        Retry();
    }
}

event ResolveFailed()
{
    `hrlog("failed to resolve host");
    Retry();
}

event Opened()
{
    ClearTimer('CheckResolveStatus');
    RetryCount = 0;
    `hrlog("connected to backend");
}

event Closed()
{
    `hrlog("connection closed");
    Retry();
}

event Tick(float DeltaTime)
{
    super.Tick(DeltaTime);

    if (bConfigured && IsConnected())
    {
        PerformIO();
    }
}

final private function PerformIO()
{
    // 1. Pick item from queue.
    // 2. Convert into byte array.
    // 3. Send binary.

    if (SendQueue.Length == 0)
    {
        return;
    }

    SendBufferSize = SendQueue[0].Size;

    // Header.
    SendBuffer[0] = SendBufferSize;
    SendBuffer[1] = SendQueue[0].ProtocolVersion;
    SendBuffer[2] = SendQueue[0].PacketID;

    DataBufferSize = 4;
    DataBuffer[0] = SendQueue[0].Data[0];
    DataBuffer[1] = SendQueue[0].Data[1];
    DataBuffer[2] = SendQueue[0].Data[2];
    DataBuffer[3] = SendQueue[0].Data[3];

    `hrlog("DataBuffer[0]:" @ ToHex(DataBuffer[0]));
    `hrlog("DataBuffer[1]:" @ ToHex(DataBuffer[1]));
    `hrlog("DataBuffer[2]:" @ ToHex(DataBuffer[2]));
    `hrlog("DataBuffer[3]:" @ ToHex(DataBuffer[3]));

    XXTEA_Encrypt(DataBuffer, DataBufferSize);

    `hrlog("DataBuffer[0]:" @ ToHex(DataBuffer[0]));
    `hrlog("DataBuffer[1]:" @ ToHex(DataBuffer[1]));
    `hrlog("DataBuffer[2]:" @ ToHex(DataBuffer[2]));
    `hrlog("DataBuffer[3]:" @ ToHex(DataBuffer[3]));

    // 64-bit unique ID.
    SendBuffer[ 3] = (DataBuffer[0] >> 24) & 0xff;
    SendBuffer[ 4] = (DataBuffer[0] >> 16) & 0xff;
    SendBuffer[ 5] = (DataBuffer[0] >>  8) & 0xff;
    SendBuffer[ 6] = (DataBuffer[0]      ) & 0xff;
    SendBuffer[ 7] = (DataBuffer[1] >> 24) & 0xff;
    SendBuffer[ 8] = (DataBuffer[1] >> 16) & 0xff;
    SendBuffer[ 9] = (DataBuffer[1] >>  8) & 0xff;
    SendBuffer[10] = (DataBuffer[1]      ) & 0xff;

    // 32-bit float.
    SendBuffer[11] = (DataBuffer[2] >> 24) & 0xff;
    SendBuffer[12] = (DataBuffer[2] >> 16) & 0xff;
    SendBuffer[13] = (DataBuffer[2] >>  8) & 0xff;
    SendBuffer[14] = (DataBuffer[2]      ) & 0xff;

    // PKCS#7.
    SendBuffer[16] = (DataBuffer[3] >> 24) & 0xff;
    SendBuffer[17] = (DataBuffer[3] >> 16) & 0xff;
    SendBuffer[18] = (DataBuffer[3] >>  8) & 0xff;
    SendBuffer[19] = (DataBuffer[3]      ) & 0xff;

    SendBinary(SendBufferSize, SendBuffer);
    SendQueue.Remove(0, 1);
}

final private function XXTEA_Encrypt(out int Data[31], int DataSize)
{
    local int Y;
    local int Z;
    local int Sum;
    local int P;
    local int Rounds;
    local int E;

    `hrdebug("DELTA :" @ DELTA);

    Rounds = 6 + 52 / DataSize;
    Sum = 0;
    Z = Data[DataSize - 1];

    while (Rounds-- > 0)
    {
        Sum += DELTA;
        E = (Sum >> 2) & 3;

        `hrdebug("Rounds :" @ Rounds);
        `hrdebug("Sum    :" @ ToHex(Sum));
        `hrdebug("E      :" @ ToHex(E));

        for (P = 0; P < DataSize - 1; ++P)
        {
            Y = Data[P + 1];
            Z = Data[P] += `MX;

            `hrdebug("P       :" @ P);
            `hrdebug("Z       :" @ ToHex(Z));
            `hrdebug("Data[P] :" @ ToHex(Data[P]));
        }

        Y = Data[0];
        Z = Data[DataSize - 1] += `MX;

        `hrdebug("Data[DataSize - 1] :" @ ToHex(Data[DataSize - 1]));
        `hrdebug("Y                  :" @ ToHex(Y));
        `hrdebug("Z                  :" @ ToHex(Z));
    }
}

final private function string WinSockErrorToString(int Error)
{
    switch (Error)
    {
        case 6:
            return "WSA_INVALID_HANDLE";
        case 8:
            return "WSA_NOT_ENOUGH_MEMORY";
        case 87:
            return "WSA_INVALID_PARAMETER";
        case 995:
            return "WSA_OPERATION_ABORTED";
        case 996:
            return "WSA_IO_INCOMPLETE";
        case 997:
            return "WSA_IO_PENDING";
        case 10004:
            return "WSAEINTR";
        case 10009:
            return "WSAEBADF";
        case 10013:
            return "WSAEACCES";
        case 10014:
            return "WSAEFAULT";
        case 10022:
            return "WSAEINVAL";
        case 10024:
            return "WSAEMFILE";
        case 10035:
            return "WSAEWOULDBLOCK";
        case 10036:
            return "WSAEINPROGRESS";
        case 10037:
            return "WSAEALREADY";
        case 10038:
            return "WSAENOTSOCK";
        case 10039:
            return "WSAEDESTADDRREQ";
        case 10040:
            return "WSAEMSGSIZE";
        case 10041:
            return "WSAEPROTOTYPE";
        case 10042:
            return "WSAENOPROTOOPT";
        case 10043:
            return "WSAEPROTONOSUPPORT";
        case 10044:
            return "WSAESOCKTNOSUPPORT";
        case 10045:
            return "WSAEOPNOTSUPP";
        case 10046:
            return "WSAEPFNOSUPPORT";
        case 10047:
            return "WSAEAFNOSUPPORT";
        case 10048:
            return "WSAEADDRINUSE";
        case 10049:
            return "WSAEADDRNOTAVAIL";
        case 10050:
            return "WSAENETDOWN";
        case 10051:
            return "WSAENETUNREACH";
        case 10052:
            return "WSAENETRESET";
        case 10053:
            return "WSAECONNABORTED";
        case 10054:
            return "WSAECONNRESET";
        case 10055:
            return "WSAENOBUFS";
        case 10056:
            return "WSAEISCONN";
        case 10057:
            return "WSAENOTCONN";
        case 10058:
            return "WSAESHUTDOWN";
        case 10059:
            return "WSAETOOMANYREFS";
        case 10060:
            return "WSAETIMEDOUT";
        case 10061:
            return "WSAECONNREFUSED";
        case 10062:
            return "WSAELOOP";
        case 10063:
            return "WSAENAMETOOLONG";
        case 10064:
            return "WSAEHOSTDOWN";
        case 10065:
            return "WSAEHOSTUNREACH";
        case 10066:
            return "WSAENOTEMPTY";
        case 10067:
            return "WSAEPROCLIM";
        case 10068:
            return "WSAEUSERS";
        case 10069:
            return "WSAEDQUOT";
        case 10070:
            return "WSAESTALE";
        case 10071:
            return "WSAEREMOTE";
        case 10091:
            return "WSASYSNOTREADY";
        case 10092:
            return "WSAVERNOTSUPPORTED";
        case 10093:
            return "WSANOTINITIALISED";
        case 10101:
            return "WSAEDISCON";
        case 10102:
            return "WSAENOMORE";
        case 10103:
            return "WSAECANCELLED";
        case 10104:
            return "WSAEINVALIDPROCTABLE";
        case 10105:
            return "WSAEINVALIDPROVIDER";
        case 10106:
            return "WSAEPROVIDERFAILEDINIT";
        case 10107:
            return "WSASYSCALLFAILURE";
        case 10108:
            return "WSASERVICE_NOT_FOUND";
        case 10109:
            return "WSATYPE_NOT_FOUND";
        case 10110:
            return "WSA_E_NO_MORE";
        case 10111:
            return "WSA_E_CANCELLED";
        case 10112:
            return "WSAEREFUSED";
        case 11001:
            return "WSAHOST_NOT_FOUND";
        case 11002:
            return "WSATRY_AGAIN";
        case 11003:
            return "WSANO_RECOVERY";
        case 11004:
            return "WSANO_DATA";
        case 11005:
            return "WSA_QOS_RECEIVERS";
        case 11006:
            return "WSA_QOS_SENDERS";
        case 11007:
            return "WSA_QOS_NO_SENDERS";
        case 11008:
            return "WSA_QOS_NO_RECEIVERS";
        case 11009:
            return "WSA_QOS_REQUEST_CONFIRMED";
        case 11010:
            return "WSA_QOS_ADMISSION_FAILURE";
        case 11011:
            return "WSA_QOS_POLICY_FAILURE";
        case 11012:
            return "WSA_QOS_BAD_STYLE";
        case 11013:
            return "WSA_QOS_BAD_OBJECT";
        case 11014:
            return "WSA_QOS_TRAFFIC_CTRL_ERROR";
        case 11015:
            return "WSA_QOS_GENERIC_ERROR";
        case 11016:
            return "WSA_QOS_ESERVICETYPE";
        case 11017:
            return "WSA_QOS_EFLOWSPEC";
        case 11018:
            return "WSA_QOS_EPROVSPECBUF";
        case 11019:
            return "WSA_QOS_EFILTERSTYLE";
        case 11020:
            return "WSA_QOS_EFILTERTYPE";
        case 11021:
            return "WSA_QOS_EFILTERCOUNT";
        case 11022:
            return "WSA_QOS_EOBJLENGTH";
        case 11023:
            return "WSA_QOS_EFLOWCOUNT";
        case 11024:
            return "WSA_QOS_EUNKOWNPSOBJ";
        case 11025:
            return "WSA_QOS_EPOLICYOBJ";
        case 11026:
            return "WSA_QOS_EFLOWDESC";
        case 11027:
            return "WSA_QOS_EPSFLOWSPEC";
        case 11028:
            return "WSA_QOS_EPSFILTERSPEC";
        case 11029:
            return "WSA_QOS_ESDMODEOBJ";
        case 11030:
            return "WSA_QOS_ESHAPERATEOBJ";
        case 11031:
            return "WSA_QOS_RESERVED_PETYPE";
        default:
            return string(Error);
    }
}

DefaultProperties
{
    TickGroup=TG_DuringAsyncWork
    LinkMode=MODE_Binary
    ProtocolVersion=`HR_PROTO_VERSION
    MaxSendQueueLength=1000
    bRetryOnFail=True
    bConfigured=False
    XXTEAKey(0)=0x2b959f13
    XXTEAKey(1)=0x330de56a
    XXTEAKey(2)=0x583e0f76
    XXTEAKey(3)=0x6b8f3054
}
