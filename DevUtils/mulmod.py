import numpy as np

"""
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
"""


# noinspection DuplicatedCode
def mulmod(x: np.uint32, y: np.uint32, p: np.uint32) -> np.uint32:
    res = np.uint32(1)
    x %= p

    while y > 0:
        # If y is odd, multiply x with result.
        if y & 1:
            res = (res * x) % p

        # y must be even now.
        y >>= 1  # y /= 2
        x = (x * x) % p

    return res


def main():
    # p1 = mulmod(np.uint32(7), np.uint32(1466838298), np.uint32(0x71d0d8bf))
    # p2 = mulmod(np.uint32(7), np.uint32(1564871020), np.uint32(0x71d0d8bf))
    # p3 = mulmod(np.uint32(7), np.uint32(532548187), np.uint32(0x71d0d8bf))
    # p4 = mulmod(np.uint32(7), np.uint32(1970507325), np.uint32(0x71d0d8bf))
    # p1 = mulmod(np.uint32(5), np.uint32(1), np.uint32(0x71d0d8bf))
    # p2 = mulmod(np.uint32(5), np.uint32(2), np.uint32(0x71d0d8bf))
    # p3 = mulmod(np.uint32(5), np.uint32(3), np.uint32(0x71d0d8bf))
    # p4 = mulmod(np.uint32(5), np.uint32(4), np.uint32(0x71d0d8bf))
    p1 = mulmod(5, 1, 0x71d0d8bf)
    p2 = mulmod(5, 2, 0x71d0d8bf)
    p3 = mulmod(5, 3, 0x71d0d8bf)
    p4 = mulmod(5, 4, 0x71d0d8bf)
    print(p1)
    print(p2)
    print(p3)
    print(p4)

    # print(mulmod(np.uint32(0x264E0000), p1, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(0x00001391), p2, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(0x66310000), p3, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(0x000066F0), p4, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(1), p1, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(2), p2, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(3), p3, np.uint32(0x71d0d8bf)))
    # print(mulmod(np.uint32(4), p4, np.uint32(0x71d0d8bf)))
    print(mulmod(1, p1, 0x71d0d8bf))
    print(mulmod(2, p2, 0x71d0d8bf))
    print(mulmod(3, p3, 0x71d0d8bf))
    print(mulmod(4, p4, 0x71d0d8bf))


if __name__ == "__main__":
    main()
