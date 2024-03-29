// SHA-1 hashing based on Sha1HashLib.uc with some modifications.
// See also: https://beyondunrealwiki.github.io/pages/sha1hash.html.
class HRSha1_V1 extends Object
    abstract;

var private int Hash[5];
var private array<byte> Data;

final function GetHash(
    const out array<byte> InputData,
    out int out_Hash[4],
    optional bool bNoNegatives = False)
{
    local array<byte> GoodIndices;
    local array<byte> BadIndices;
    local byte Idx;

    Data = InputData;
    CalcHash();

    if (bNoNegatives)
    {
        for (Idx = 0; Idx < ArrayCount(Hash); ++Idx)
        {
            if (Hash[Idx] > 0)
            {
                GoodIndices.AddItem(Idx);
            }
            else
            {
                BadIndices.AddItem(Idx);
            }
        }

        // Got enough positive integers -> just get them.
        if (GoodIndices.Length >= ArrayCount(out_Hash))
        {
            out_Hash[0] = Hash[GoodIndices[0]];
            out_Hash[1] = Hash[GoodIndices[1]];
            out_Hash[2] = Hash[GoodIndices[2]];
            out_Hash[3] = Hash[GoodIndices[3]];
            return;
        }

        // Did not get enough positive integers -> get the ones
        // that are positive and handle the rest with some trickery.
        for (Idx = 0; Idx < GoodIndices.Length; ++Idx)
        {
            out_Hash[Idx] = Hash[GoodIndices[Idx]];
        }

        while (Idx < ArrayCount(out_Hash))
        {
            out_hash[Idx] = -Hash[BadIndices.Length];
            ++Idx;
            BadIndices.Length = BadIndices.Length - 1;
        }
    }
    else
    {
        out_Hash[0] = Hash[0];
        out_Hash[1] = Hash[1];
        out_Hash[2] = Hash[2];
        out_Hash[3] = Hash[3];
    }
}

private final function CalcHash()
{
    local int Idx, Chunk, Tmp;
    local int A, B, C, D, E;
    local int W[80];

    // Initialize the result.
    Hash[0] = 0x67452301;
    Hash[1] = 0xEFCDAB89;
    Hash[2] = 0x98BADCFE;
    Hash[3] = 0x10325476;
    Hash[4] = 0xC3D2E1F0;

    // Initialize the Data.
    Idx = Data.Length;
    if (Idx % 64 < 56)
    {
        Data.Length = Data.Length + 64 - Idx % 64;
    }
    else
    {
        Data.Length = Data.Length + 128 - Idx % 64;
    }

    Data[Idx] = 0x80;
    Data[Data.Length - 5] = Idx >>> 29;
    Data[Data.Length - 4] = Idx >>> 21;
    Data[Data.Length - 3] = Idx >>> 13;
    Data[Data.Length - 2] = Idx >>> 5;
    Data[Data.Length - 1] = Idx << 3;

    // The transformation stuff.
    while (Chunk * 64 < Data.Length)
    {
        for (Idx = 0; Idx < 16; ++Idx)
        {
            W[Idx] =  (Data[Chunk * 64 + Idx * 4]     << 24)
                    | (Data[Chunk * 64 + Idx * 4 + 1] << 16)
                    | (Data[Chunk * 64 + Idx * 4 + 2] <<  8)
                    |  Data[Chunk * 64 + Idx * 4 + 3];
        }

        for (Idx = 16; Idx < 80; ++Idx)
        {
            Tmp = W[Idx - 3] ^ W[Idx - 8] ^ W[Idx - 14] ^ W[Idx - 16];
            W[Idx] = (Tmp << 1) | (Tmp >>> 31);
        }

        A = Hash[0];
        B = Hash[1];
        C = Hash[2];
        D = Hash[3];
        E = Hash[4];

        // Round 1.
        E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + W[ 0] + 0x5A827999;        B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + W[ 1] + 0x5A827999;        A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + W[ 2] + 0x5A827999;        E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + W[ 3] + 0x5A827999;        D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + W[ 4] + 0x5A827999;        C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + W[ 5] + 0x5A827999;        B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + W[ 6] + 0x5A827999;        A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + W[ 7] + 0x5A827999;        E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + W[ 8] + 0x5A827999;        D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + W[ 9] + 0x5A827999;        C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + W[10] + 0x5A827999;        B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + W[11] + 0x5A827999;        A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + W[12] + 0x5A827999;        E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + W[13] + 0x5A827999;        D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + W[14] + 0x5A827999;        C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + W[15] + 0x5A827999;        B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + W[16] + 0x5A827999;        A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + W[17] + 0x5A827999;        E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + W[18] + 0x5A827999;        D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + W[19] + 0x5A827999;        C = (C << 30) | (C >>> -30);

        // Round 2.
        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[20] + 0x6ED9EBA1;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[21] + 0x6ED9EBA1;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[22] + 0x6ED9EBA1;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[23] + 0x6ED9EBA1;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[24] + 0x6ED9EBA1;                C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[25] + 0x6ED9EBA1;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[26] + 0x6ED9EBA1;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[27] + 0x6ED9EBA1;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[28] + 0x6ED9EBA1;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[29] + 0x6ED9EBA1;                C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[30] + 0x6ED9EBA1;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[31] + 0x6ED9EBA1;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[32] + 0x6ED9EBA1;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[33] + 0x6ED9EBA1;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[34] + 0x6ED9EBA1;                C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[35] + 0x6ED9EBA1;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[36] + 0x6ED9EBA1;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[37] + 0x6ED9EBA1;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[38] + 0x6ED9EBA1;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[39] + 0x6ED9EBA1;                C = (C << 30) | (C >>> -30);

        // Round 3.
        E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + W[40] + 0x8F1BBCDC;	B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + W[41] + 0x8F1BBCDC;	A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + W[42] + 0x8F1BBCDC;	E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + W[43] + 0x8F1BBCDC;	D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + W[44] + 0x8F1BBCDC;	C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + W[45] + 0x8F1BBCDC;	B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + W[46] + 0x8F1BBCDC;	A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + W[47] + 0x8F1BBCDC;	E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + W[48] + 0x8F1BBCDC;	D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + W[49] + 0x8F1BBCDC;	C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + W[50] + 0x8F1BBCDC;	B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + W[51] + 0x8F1BBCDC;	A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + W[52] + 0x8F1BBCDC;	E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + W[53] + 0x8F1BBCDC;	D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + W[54] + 0x8F1BBCDC;	C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + W[55] + 0x8F1BBCDC;	B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + W[56] + 0x8F1BBCDC;	A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + W[57] + 0x8F1BBCDC;	E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + W[58] + 0x8F1BBCDC;	D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + W[59] + 0x8F1BBCDC;	C = (C << 30) | (C >>> -30);

        // Round 4.
        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[60] + 0xCA62C1D6;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[61] + 0xCA62C1D6;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[62] + 0xCA62C1D6;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[63] + 0xCA62C1D6;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[64] + 0xCA62C1D6;                C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[65] + 0xCA62C1D6;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[66] + 0xCA62C1D6;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[67] + 0xCA62C1D6;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[68] + 0xCA62C1D6;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[69] + 0xCA62C1D6;                C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[70] + 0xCA62C1D6;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[71] + 0xCA62C1D6;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[72] + 0xCA62C1D6;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[73] + 0xCA62C1D6;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[74] + 0xCA62C1D6;                C = (C << 30) | (C >>> -30);

        E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + W[75] + 0xCA62C1D6;                B = (B << 30) | (B >>> -30);
        D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + W[76] + 0xCA62C1D6;                A = (A << 30) | (A >>> -30);
        C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + W[77] + 0xCA62C1D6;                E = (E << 30) | (E >>> -30);
        B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + W[78] + 0xCA62C1D6;                D = (D << 30) | (D >>> -30);
        A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + W[79] + 0xCA62C1D6;                C = (C << 30) | (C >>> -30);

        Hash[0] += A;
        Hash[1] += B;
        Hash[2] += C;
        Hash[3] += D;
        Hash[4] += E;

        ++Chunk;
    }
}
