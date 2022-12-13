class HRTcpLink_V1 extends TcpLink;

var private HRSha1_V1 Sha1Hasher;

var private int XRandSeed;

// XXTEA constants and macros.
var private int XXTEAKey[4];
`define MX (((Z>>>5^Y<<2) + (Y>>>3^Z<<4)) ^ ((Sum^Y) + (XXTEAKey[(P&3)^E] ^ Z)))
const DELTA = 0x9e3779b9;

// Diffie-Hellman key generation.
const DH_P = 0x71d0d8bf;
const DH_G = 7;
var private int DH_PrivateKey[4];
var private int DH_PublicKey[4];
var private int DH_PeerPublicKey[4];

var private bool bDHReady;

var enum DHLocalState
{
    DHLS_None,
    DHLS_KeyPairGenerated,
    DHLS_PublicKeySent,
    DHLS_SharedSecretGenerated
} DH_LocalState;

var enum DHRemoteState
{
    DHRS_None,
    DHRS_PublicKeyReceived
} DH_RemoteState;

enum EPacketID
{
    EPID_Empty,
    EPID_DH_PublicKey,
    EPID_FinishedRaceStats,
};

`define HR_PROTO_VERSION 1
const HEADER_BYTES = 3;
const DH_PUBLIC_KEY_BYTES = 19;

struct HRPacket_V1
{
    // TODO: 4-byte field for size + sequence number? CRC32?
    var byte Size;
    var byte ProtocolVersion;
    var byte PacketID;

    var byte Checksum[4];
    var byte Signature[16];

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

event PostBeginPlay()
{
    super.PostBeginPlay();

    XRandSeed = Rand(MaxInt);

    DH_LocalState = DHLS_None;
    DH_RemoteState = DHRS_None;

    if (Sha1Hasher == None)
    {
        Sha1Hasher = new(self) class'HRSha1_V1';
    }

    LinkMode = MODE_Binary;
    ReceiveMode = RMODE_Event;

    SetTimer(FClamp(FRand() * 15.0, 5.0, 15.0), False, 'DH_Generate_KeyPair');
}

final function SendFinishedRaceStats(const out RaceStatsComplex_V1 RaceStats)
{
    local HRPacket_V1 Packet;
    local int Test1;
    local int Test2;

    if (SendQueue.Length >= MaxSendQueueLength)
    {
        `hrerror("MaxSendQueueLength reached, dropping packet");
    }

    // Header.
    Packet.Size = 19;
    Packet.ProtocolVersion = ProtocolVersion;
    Packet.PacketID = EPID_FinishedRaceStats;

    // Payload data.
    Packet.Data[0] = RaceStats.RacePRI.UniqueId.Uid.A;
    Packet.Data[1] = RaceStats.RacePRI.UniqueId.Uid.B;
    `hrdebug("RaceStats.RaceFinish:" @ RaceStats.RaceFinish);
    Packet.Data[2] = (
          ((RaceStats.RaceFinish       ) & 0xff)
        | ((RaceStats.RaceFinish >>>  8) & 0xff)
        | ((RaceStats.RaceFinish >>> 16) & 0xff)
        | ((RaceStats.RaceFinish >>> 24) & 0xff)
    );
    `hrdebug("Packet.Data[2]:" @ Packet.Data[2]);

    // This does not work.
    // Test = (
    //       ((RaceStats.RaceFinish       ) & 0xff)
    //     | ((RaceStats.RaceFinish >>>  8) & 0xff)
    //     | ((RaceStats.RaceFinish >>> 16) & 0xff)
    //     | ((RaceStats.RaceFinish >>> 24) & 0xff)
    // );

    // Have to send floats as 2 ints?
    // 99999.666666 -> 99999 + 666666
    Test1 = RaceStats.RaceFinish;
    Test2 = Round((RaceStats.RaceFinish - int(RaceStats.RaceFinish)) * 1000000);
    `hrdebug("Test1:" @ Test1);
    `hrdebug("Test2:" @ Test2);

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
    return FClamp(1.0 + (RetryCount / 10), 1.0, 4.0);
}

final private function float GetRetryDelay()
{
    return FClamp(2.0 ** RetryCount, 2.0, 30.0);
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
            `hrwarn("last WinSock error was:" @ class'HRNetUtils_V1'.static.WinSockErrorToString(Error));
        }
        ++RetryCount;
        SetTimer(GetRetryDelay() + GetTimeout(), False, 'CheckResolveStatus');
        SetTimer(GetRetryDelay(), False, 'ResolveBackend');
    }
}

final function CloseLink()
{
    bRetryOnFail = False;
    SendBinary(0, SendBuffer);
    Close();
}

event Resolved(IpAddr Addr)
{
    local int LocalPort;

    `hrlog(BackendHost @ "resolved to:" @ IpAddrToString(Addr));

    Addr.Port = BackendPort;

    LocalPort = BindPort();
    if (LocalPort > 0)
    {
        `hrlog("bound on local port:" @ LocalPort);
    }
    else
    {
        `hrlog("failed to bind local port");
        Retry();
    }

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

    // TODO: DH timeouts?
    // 1. send my public key
    // 2. wait for remote public key
    // 3. generate shared secret
    // 4. handshake messages?
    // 5. begin normal IO

    if (!bDHReady)
    {
        switch (DH_LocalState)
        {
            case DHLS_None:
            case DHLS_KeyPairGenerated:
                DH_Send_PublicKey();
            case DHLS_PublicKeySent:
                if (DH_RemoteState == DHRS_PublicKeyReceived)
                {
                    DH_Generate_SharedSecret();
                }
                break;
            case DHLS_SharedSecretGenerated:
                break;
        }

        // switch (DH_RemoteState)
        // {
        //     case DHRS_None:
        //         break;
        //     case DHRS_PublicKeyReceived:
        //         break;
        // }

        bDHReady = (DH_LocalState == DHLS_SharedSecretGenerated)
            && (DH_RemoteState == DHRS_PublicKeyReceived);

        // Check DH state again on next tick.
        return;
    }

    if (bConfigured && IsConnected())
    {
        PerformIO();
    }
}

event ReceivedBinary(int Count, byte B[255])
{
    local int Idx;
    local byte Size;
    local byte PacketProtoVersion;
    local EPacketID PacketID;

    `hrdebug("Count:" @ Count);

    for (Idx = 0; Idx < Count; ++Idx)
    {
        `hrdebug(Idx @ ":" @ B[Idx]);
    }

    if (Count > 0)
    {
        Size = B[0];
    }
    else
    {
        return;
    }

    if (Size >= HEADER_BYTES)
    {
        PacketProtoVersion = B[1];
        PacketID = EPacketID(B[2]);
    }
    else
    {
        return;
    }

    if (PacketProtoVersion != ProtocolVersion)
    {
        `hrwarn("received invalid packet protocol version:" @ PacketProtoVersion);
        return;
    }

    switch (PacketID)
    {
        case EPID_DH_PublicKey:
            HandleRecv_EPID_DH_PublicKey(Size, B);
            break;
        default:
            `hrwarn("received invalid packet ID:" @ PacketID);
    }
}

final private function HandleRecv_EPID_DH_PublicKey(byte PacketSize, const out byte B[255])
{
    if (PacketSize < DH_PUBLIC_KEY_BYTES)
    {
        `hrwarn("did not receive enough bytes");
        return;
    }

    DH_PeerPublicKey[0] = (
           (B[ 3]        & 0xff)
        | ((B[ 4] <<  8) & 0xff)
        | ((B[ 5] << 16) & 0xff)
        | ((B[ 6] << 24) & 0xff)
    );
    DH_PeerPublicKey[1] = (
           (B[ 7]        & 0xff)
        | ((B[ 8] <<  8) & 0xff)
        | ((B[ 9] << 16) & 0xff)
        | ((B[10] << 24) & 0xff)
    );
    DH_PeerPublicKey[2] = (
           (B[11]        & 0xff)
        | ((B[12] <<  8) & 0xff)
        | ((B[13] << 16) & 0xff)
        | ((B[14] << 24) & 0xff)
    );
    DH_PeerPublicKey[3] = (
           (B[15]        & 0xff)
        | ((B[16] <<  8) & 0xff)
        | ((B[17] << 16) & 0xff)
        | ((B[18] << 24) & 0xff)
    );

    DH_RemoteState = DHRS_PublicKeyReceived;
}

final private function PerformIO()
{
    local int Idx;

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

    `hrdebug("DataBuffer[0]:" @ ToHex(DataBuffer[0]));
    `hrdebug("DataBuffer[0]:" @ DataBuffer[0]);
    `hrdebug("DataBuffer[1]:" @ ToHex(DataBuffer[1]));
    `hrdebug("DataBuffer[1]:" @ DataBuffer[1]);
    `hrdebug("DataBuffer[2]:" @ ToHex(DataBuffer[2]));
    `hrdebug("DataBuffer[2]:" @ DataBuffer[2]);
    `hrdebug("DataBuffer[3]:" @ ToHex(DataBuffer[3]));
    `hrdebug("DataBuffer[3]:" @ DataBuffer[3]);

    XXTEA_Encrypt(DataBuffer, DataBufferSize);

    `hrdebug("DataBuffer[0]:" @ ToHex(DataBuffer[0]));
    `hrdebug("DataBuffer[0]:" @ DataBuffer[0]);
    `hrdebug("DataBuffer[1]:" @ ToHex(DataBuffer[1]));
    `hrdebug("DataBuffer[1]:" @ DataBuffer[1]);
    `hrdebug("DataBuffer[2]:" @ ToHex(DataBuffer[2]));
    `hrdebug("DataBuffer[2]:" @ DataBuffer[2]);
    `hrdebug("DataBuffer[3]:" @ ToHex(DataBuffer[3]));
    `hrdebug("DataBuffer[3]:" @ DataBuffer[3]);

    // 64-bit unique ID.
    SendBuffer[ 3] = (DataBuffer[0]       ) & 0xff;
    SendBuffer[ 4] = (DataBuffer[0] >>>  8) & 0xff;
    SendBuffer[ 5] = (DataBuffer[0] >>> 16) & 0xff;
    SendBuffer[ 6] = (DataBuffer[0] >>> 24) & 0xff;
    SendBuffer[ 7] = (DataBuffer[1]       ) & 0xff;
    SendBuffer[ 8] = (DataBuffer[1] >>>  8) & 0xff;
    SendBuffer[ 9] = (DataBuffer[1] >>> 16) & 0xff;
    SendBuffer[10] = (DataBuffer[1] >>> 24) & 0xff;

    // 32-bit float.
    SendBuffer[11] = (DataBuffer[2]       ) & 0xff;
    SendBuffer[12] = (DataBuffer[2] >>>  8) & 0xff;
    SendBuffer[13] = (DataBuffer[2] >>> 16) & 0xff;
    SendBuffer[14] = (DataBuffer[2] >>> 24) & 0xff;

    // PKCS#7.
    SendBuffer[15] = (DataBuffer[3]       ) & 0xff;
    SendBuffer[16] = (DataBuffer[3] >>>  8) & 0xff;
    SendBuffer[17] = (DataBuffer[3] >>> 16) & 0xff;
    SendBuffer[18] = (DataBuffer[3] >>> 24) & 0xff;

    for (Idx = 0; Idx < SendBufferSize; ++Idx)
    {
        `hrdebug(Idx @ ":" @ SendBuffer[Idx]);
    }

    SendBinary(SendBufferSize, SendBuffer);

    // `hrdebug("decrypting...");
    XXTEA_Decrypt(DataBuffer, DataBufferSize);

    `hrdebug("DataBuffer[0]:" @ ToHex(DataBuffer[0]));
    `hrdebug("DataBuffer[0]:" @ DataBuffer[0]);
    `hrdebug("DataBuffer[1]:" @ ToHex(DataBuffer[1]));
    `hrdebug("DataBuffer[1]:" @ DataBuffer[1]);
    `hrdebug("DataBuffer[2]:" @ ToHex(DataBuffer[2]));
    `hrdebug("DataBuffer[2]:" @ DataBuffer[2]);
    `hrdebug("DataBuffer[3]:" @ ToHex(DataBuffer[3]));
    `hrdebug("DataBuffer[3]:" @ DataBuffer[3]);

    SendQueue.Remove(0, 1);
}

// final private function int MXDebug(int Z, int Y, int Sum, int E, int P)
// {
//     local int a, b, c, d, ee, f, g;

//     a = (z >>> 5 ^ y << 2);
//     `hrdebug("a :" @ ToHex(a));
//     b = (y >>> 3 ^ z << 4);
//     `hrdebug("b :" @ ToHex(a));
//     c = a + b;
//     `hrdebug("c :" @ ToHex(c));

//     d = (sum ^ y);
//     `hrdebug("d :" @ ToHex(d));
//     ee = (XXTEAKey[(p & 3) ^ e] ^ z);
//     `hrdebug("ee:" @ ToHex(ee));
//     f = d + ee;
//     `hrdebug("f :" @ ToHex(f));

//     g = c ^ f;
//     `hrdebug("g :" @ ToHex(g));

//     return g;
// }

final private function XXTEA_Decrypt(out int Data[31], int DataSize)
{
    local int Y;
    local int Z;
    local int Sum;
    local int P;
    local int Rounds;
    local int E;

    Rounds = 6 + 52 / DataSize;

    if (DataSize > 1)
    {
        Sum = Rounds * DELTA;
        Y = Data[0];

        while (Rounds-- > 0)
        {
            E = (Sum >>> 2) & 3;

            // `hrdebug("Rounds :" @ Rounds);
            // `hrdebug("Sum    :" @ ToHex(Sum));
            // `hrdebug("E      :" @ ToHex(E));

            for (P = DataSize - 1; P > 0; --P)
            {
                Z = Data[P - 1];
                Y = Data[P] -= `MX;

                // `hrdebug(ToHex(MXDebug(Z, Y, Sum, E, P)));

                // `hrdebug("P       :" @ P);
                // `hrdebug("Y       :" @ ToHex(Y));
                // `hrdebug("Z       :" @ ToHex(Z));
                // `hrdebug("Data[P] :" @ ToHex(Data[P]));
            }

            Z = Data[DataSize - 1];
            Y = Data[0] -= `MX;
            Sum -= DELTA;

            // `hrdebug("Data[DataSize - 1] :" @ ToHex(Data[DataSize - 1]));
            // `hrdebug("Y                  :" @ ToHex(Y));
            // `hrdebug("Z                  :" @ ToHex(Z));
        }
    }
}

final private function XXTEA_Encrypt(out int Data[31], int DataSize)
{
    local int Y;
    local int Z;
    local int Sum;
    local int P;
    local int Rounds;
    local int E;

    // `hrdebug("DELTA :" @ DELTA);

    Rounds = 6 + 52 / DataSize;
    Sum = 0;
    Z = Data[DataSize - 1];

    while (Rounds-- > 0)
    {
        Sum += DELTA;
        E = (Sum >>> 2) & 3;

        // `hrdebug("Rounds :" @ Rounds);
        // `hrdebug("Sum    :" @ ToHex(Sum));
        // `hrdebug("E      :" @ ToHex(E));

        for (P = 0; P < DataSize - 1; ++P)
        {
            Y = Data[P + 1];
            Z = Data[P] += `MX;

            // `hrdebug("P       :" @ P);
            // `hrdebug("Z       :" @ ToHex(Z));
            // `hrdebug("Data[P] :" @ ToHex(Data[P]));
        }

        Y = Data[0];
        Z = Data[DataSize - 1] += `MX;

        // `hrdebug("Data[DataSize - 1] :" @ ToHex(Data[DataSize - 1]));
        // `hrdebug("Y                  :" @ ToHex(Y));
        // `hrdebug("Z                  :" @ ToHex(Z));
    }
}

final private function int PowMod(int Base, int Exp, int Modulus)
{
    local int Res;

    Res = 1;
    Base = Base % Base;

    while (Exp > 0)
    {
        // If Exp is odd, multiply Base with result.
        if ((Exp & 1) > 0)
        {
            Res = (Res * Base) % Modulus;
        }

        // Exp must be even now.
        Exp = Exp >>> 1;  // Y /= 2
        Base = (Base * Base) % Modulus;
    }

    return Res;
}

// Based on glibc.
final private function int _XRand()
{
    XRandSeed = ((XRandSeed * 1103515245) + 12345) & 0x7fffffff;
    return XRandSeed;
}

// Less shitty RNG than just Rand() but still pretty shit.
final private function int XRand()
{
    local int X;
    local int T;

    X = Rand(MaxInt);

    // `hrdebug("Rand()   :" @ ToHex(X));
    // `hrdebug("_XRand() :" @ ToHex(_XRand()));

    T = (X ^ (X >>> 8)) & _XRand(); X = X ^ T ^ (T << 8);
    T = (X ^ (X >>> 4)) & _XRand(); X = X ^ T ^ (T << 4);
    T = (X ^ (X >>> 2)) & _XRand(); X = X ^ T ^ (T << 2);
    T = (X ^ (X >>> 1)) & _XRand();

    return X ^ T ^ (T << 1);
}

final private function DH_Generate_KeyPair()
{
    local array<byte> Seed;
    local IpAddr LocalIP;
    local int Idx;
    local int StrLen;
    local int Tmp;
    local int Char;
    local PlayerReplicationInfo PRI;

`ifdef(HRDEBUG)
    local string XRandTest;

    for (Tmp = 0; Tmp < 10; ++Tmp)
    {
        `hrdebug("XRand():" @ ToHex(XRand()));
    }

    for (Tmp = 0; Tmp < 100; ++Tmp)
    {
        for (Idx = 0; Idx < 25; ++Idx)
        {
            Char = XRand();
            XRandTest $= byte((Char       ) & 0xff) $ ",";
            XRandTest $= byte((Char >>>  8) & 0xff) $ ",";
            XRandTest $= byte((Char >>> 16) & 0xff) $ ",";
            XRandTest $= byte((Char >>> 24) & 0xff) $ ",";
        }
        `hrdebug(XRandTest);
        XRandTest = "";
    }

    Idx = 0;
    Tmp = 0;
    Char = 0;
`endif

    GetLocalIP(LocalIP);

    Seed.Length = 25;
    Seed[ 0] = (LocalIP.Addr       ) & 0xff;
    Seed[ 1] = (LocalIP.Addr >>>  8) & 0xff;
    Seed[ 2] = (LocalIP.Addr >>> 16) & 0xff;
    Seed[ 3] = (LocalIP.Addr >>> 24) & 0xff;
    Seed[ 4] = (LocalIP.Port       ) & 0xff;
    Seed[ 5] = (LocalIP.Port >>>  8) & 0xff;
    Seed[ 6] = (LocalIP.Port >>> 16) & 0xff;
    Seed[ 7] = (LocalIP.Port >>> 24) & 0xff;
    Tmp = XRand();
    `hrdebug("Tmp:" @ Tmp);
    Seed[ 8] = (Tmp       ) & 0xff;
    Seed[ 9] = (Tmp >>>  8) & 0xff;
    Seed[10] = (Tmp >>> 16) & 0xff;
    Seed[11] = (Tmp >>> 24) & 0xff;
    Tmp = XRand();
    `hrdebug("Tmp:" @ Tmp);
    Seed[12] = (Tmp       ) & 0xff;
    Seed[13] = (Tmp >>>  8) & 0xff;
    Seed[14] = (Tmp >>> 16) & 0xff;
    Seed[15] = (Tmp >>> 24) & 0xff;
    Tmp = XRand();
    `hrdebug("Tmp:" @ Tmp);
    Seed[16] = (Tmp       ) & 0xff;
    Seed[17] = (Tmp >>>  8) & 0xff;
    Seed[18] = (Tmp >>> 16) & 0xff;
    Seed[19] = (Tmp >>> 24) & 0xff;
    Tmp = XRand();
    `hrdebug("Tmp:" @ Tmp);
    Seed[20] = (Tmp       ) & 0xff;
    Seed[21] = (Tmp >>>  8) & 0xff;
    Seed[22] = (Tmp >>> 16) & 0xff;
    Seed[23] = (Tmp >>> 24) & 0xff;

    Seed[24] = WorldInfo.Game.GetNumPlayers();

    StrLen = Len(WorldInfo.ComputerName);
    Tmp = Seed.Length;
    Seed.Length = Tmp + StrLen;
    --Tmp;
    for (Idx = 0; Idx < StrLen; ++Idx)
    {
        Char = Asc(Mid(WorldInfo.ComputerName, Idx, 1));
        Seed[Tmp + Idx    ] = (Char       ) & 0xff;
        Seed[Tmp + Idx + 1] = (Char >>>  8) & 0xff;
        Seed[Tmp + Idx + 2] = (Char >>> 16) & 0xff;
        Seed[Tmp + Idx + 3] = (Char >>> 24) & 0xff;
    }

    ForEach DynamicActors(class'PlayerReplicationInfo', PRI)
    {
        StrLen = Len(PRI.PlayerName);
        Tmp = Seed.Length;
        Seed.Length = Tmp + StrLen;
        --Tmp;
        for (Idx = 0; Idx < StrLen; ++Idx)
        {
            Char = Asc(Mid(PRI.PlayerName, Idx, 1));
            Seed[Tmp + Idx    ] = (Char       ) & 0xff;
            Seed[Tmp + Idx + 1] = (Char >>>  8) & 0xff;
            Seed[Tmp + Idx + 2] = (Char >>> 16) & 0xff;
            Seed[Tmp + Idx + 3] = (Char >>> 24) & 0xff;
        }

        Seed[Seed.Length] = PRI.Ping;

        StrLen = Len(PRI.SavedNetworkAddress);
        Tmp = Seed.Length;
        Seed.Length = Tmp + StrLen;
        --Tmp;
        for (Idx = 0; Idx < StrLen; ++Idx)
        {
            Char = Asc(Mid(PRI.SavedNetworkAddress, Idx, 1));
            Seed[Tmp + Idx    ] = (Char       ) & 0xff;
            Seed[Tmp + Idx + 1] = (Char >>>  8) & 0xff;
            Seed[Tmp + Idx + 2] = (Char >>> 16) & 0xff;
            Seed[Tmp + Idx + 3] = (Char >>> 24) & 0xff;
        }

        Tmp = Seed.Length;
        Seed.Length = Tmp + 8;
        --Tmp;
        Seed[Tmp    ] = (PRI.UniqueId.Uid.A       ) & 0xff;
        Seed[Tmp + 1] = (PRI.UniqueId.Uid.A >>>  8) & 0xff;
        Seed[Tmp + 2] = (PRI.UniqueId.Uid.A >>> 16) & 0xff;
        Seed[Tmp + 3] = (PRI.UniqueId.Uid.A >>> 24) & 0xff;
        Seed[Tmp + 4] = (PRI.UniqueId.Uid.B       ) & 0xff;
        Seed[Tmp + 5] = (PRI.UniqueId.Uid.B >>>  8) & 0xff;
        Seed[Tmp + 6] = (PRI.UniqueId.Uid.B >>> 16) & 0xff;
        Seed[Tmp + 7] = (PRI.UniqueId.Uid.B >>> 24) & 0xff;

        if (FRand() > 0.5)
        {
            Idx = Seed.Length;
            Tmp = XRand();
            Seed[Idx    ] = (Tmp       ) & 0xff;
            Seed[Idx + 1] = (Tmp >>>  8) & 0xff;
            Seed[Idx + 2] = (Tmp >>> 16) & 0xff;
            Seed[Idx + 3] = (Tmp >>> 24) & 0xff;
        }
    }

    // TODO: Seed needs padding.

    Tmp = 0;
    Idx = 0;
    while (Idx < Seed.Length)
    {
        Char = (
               (Seed[Idx    ]        & 0xff)
            | ((Seed[Idx + 1] <<  8) & 0xff)
            | ((Seed[Idx + 2] << 16) & 0xff)
            | ((Seed[Idx + 3] << 24) & 0xff)
        );

        `hrdebug("A Seed" @ Idx @ ToHex(Char));

        Tmp = (Char ^ (Char >>> 8)) & _XRand(); Char = Char ^ Tmp ^ (Tmp << 8);
        Tmp = (Char ^ (Char >>> 4)) & _XRand(); Char = Char ^ Tmp ^ (Tmp << 4);
        Tmp = (Char ^ (Char >>> 2)) & _XRand(); Char = Char ^ Tmp ^ (Tmp << 2);
        Tmp = (Char ^ (Char >>> 1)) & _XRand(); Char = Char ^ Tmp ^ (Tmp << 1);

        Seed[Idx    ] = (Char       ) & 0xff;
        Seed[Idx + 1] = (Char >>>  8) & 0xff;
        Seed[Idx + 2] = (Char >>> 16) & 0xff;
        Seed[Idx + 3] = (Char >>> 24) & 0xff;

        Idx += 4;

        `hrdebug("B Seed" @ Idx @ ToHex(Char));
    }

    `hrdebug("Seed.Length:" @ Seed.Length);

    // XXTEA key is 128 bits -> use truncated SHA-1.
    // Doing tricks since PowMod doesn't like negative integers.
    Sha1Hasher.GetHash(Seed, DH_PrivateKey, True);

    DH_PublicKey[0] = PowMod(DH_P, DH_PrivateKey[0], DH_G);
    DH_PublicKey[1] = PowMod(DH_P, DH_PrivateKey[1], DH_G);
    DH_PublicKey[2] = PowMod(DH_P, DH_PrivateKey[2], DH_G);
    DH_PublicKey[3] = PowMod(DH_P, DH_PrivateKey[3], DH_G);

    `hrdebug("DH_PrivateKey[0]:" @ DH_PrivateKey[0]);
    `hrdebug("DH_PrivateKey[1]:" @ DH_PrivateKey[1]);
    `hrdebug("DH_PrivateKey[2]:" @ DH_PrivateKey[2]);
    `hrdebug("DH_PrivateKey[3]:" @ DH_PrivateKey[3]);

    `hrdebug("DH_PublicKey[0]:" @ DH_PublicKey[0]);
    `hrdebug("DH_PublicKey[1]:" @ DH_PublicKey[1]);
    `hrdebug("DH_PublicKey[2]:" @ DH_PublicKey[2]);
    `hrdebug("DH_PublicKey[3]:" @ DH_PublicKey[3]);

    DH_LocalState = DHLS_KeyPairGenerated;
}

final private function DH_Generate_SharedSecret()
{
    XXTEAKey[0] = PowMod(DH_PeerPublicKey[0], DH_PrivateKey[0], DH_P);
    XXTEAKey[1] = PowMod(DH_PeerPublicKey[1], DH_PrivateKey[1], DH_P);
    XXTEAKey[2] = PowMod(DH_PeerPublicKey[2], DH_PrivateKey[2], DH_P);
    XXTEAKey[3] = PowMod(DH_PeerPublicKey[3], DH_PrivateKey[3], DH_P);

    `hrdebug("XXTEAKey[0]:" @ XXTEAKey[0]);
    `hrdebug("XXTEAKey[1]:" @ XXTEAKey[1]);
    `hrdebug("XXTEAKey[2]:" @ XXTEAKey[2]);
    `hrdebug("XXTEAKey[3]:" @ XXTEAKey[3]);
}

final private function DH_Send_PublicKey()
{
    // TODO: const package sizes?
    SendBufferSize = DH_PUBLIC_KEY_BYTES;
    SendBuffer[ 0] = SendBufferSize;
    SendBuffer[ 1] = ProtocolVersion;
    SendBuffer[ 2] = EPID_DH_PublicKey;

    SendBuffer[ 3] = (DH_PublicKey[0]       ) & 0xff;
    SendBuffer[ 4] = (DH_PublicKey[0] >>>  8) & 0xff;
    SendBuffer[ 5] = (DH_PublicKey[0] >>> 16) & 0xff;
    SendBuffer[ 6] = (DH_PublicKey[0] >>> 24) & 0xff;

    SendBuffer[ 7] = (DH_PublicKey[1]       ) & 0xff;
    SendBuffer[ 8] = (DH_PublicKey[1] >>>  8) & 0xff;
    SendBuffer[ 9] = (DH_PublicKey[1] >>> 16) & 0xff;
    SendBuffer[10] = (DH_PublicKey[1] >>> 24) & 0xff;

    SendBuffer[11] = (DH_PublicKey[2]       ) & 0xff;
    SendBuffer[12] = (DH_PublicKey[2] >>>  8) & 0xff;
    SendBuffer[13] = (DH_PublicKey[2] >>> 16) & 0xff;
    SendBuffer[14] = (DH_PublicKey[2] >>> 24) & 0xff;

    SendBuffer[15] = (DH_PublicKey[3]       ) & 0xff;
    SendBuffer[16] = (DH_PublicKey[3] >>>  8) & 0xff;
    SendBuffer[17] = (DH_PublicKey[3] >>> 16) & 0xff;
    SendBuffer[18] = (DH_PublicKey[3] >>> 24) & 0xff;

    SendBinary(SendBufferSize, SendBuffer);
    DH_LocalState = DHLS_PublicKeySent;
}

DefaultProperties
{
    TickGroup=TG_DuringAsyncWork

    LinkMode=MODE_Binary
    ReceiveMode=RMODE_Event

    ProtocolVersion=`HR_PROTO_VERSION
    MaxSendQueueLength=1000

    bRetryOnFail=True
    bConfigured=False

    bDHReady=False

    // XXTEAKey(0)=0x2b959f13
    // XXTEAKey(1)=0x330de56a
    // XXTEAKey(2)=0x583e0f76
    // XXTEAKey(3)=0x6b8f3054
}
