class HRCurve25519_V1 extends Object
    abstract;

final function Donna(
    out byte Public[32],
    const out byte Secret[32],
    const out byte BasePoint[32])
{
    local HRBigInt_V1 bp[5];
    local HRBigInt_V1 x[5];
    local HRBigInt_V1 z[5];
    local HRBigInt_V1 zmone[5];
    local byte e[32];

    e[ 0] = e[ 0] & 248;
    e[31] = e[31] & 127;
    e[31] = e[31] | 64;
}
