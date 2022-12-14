import numpy as np

"""Old UnrealScript PowMod version.
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
def mul_mod(a: np.uint32, b: np.uint32, modulus: np.uint32) -> np.uint32:
    # (a * b) % modulo = (a % modulo) * (b % modulo) % modulo
    a %= modulus
    b %= modulus

    # fast path
    if a <= 0xffff and b <= 0xffff:
        return (a * b) % modulus

    # we might encounter overflows (slow path)
    # the number of loops depends on b, therefore try to minimize b
    if b > a:
        a, b = b, a

    result = np.uint32(0)

    while a > 0 and b > 0:
        # b is odd ? a * b = a + a * (b - 1)
        if b & 1:
            result += a
        if result >= modulus:
            result -= modulus
        # skip b-- because the bit-shift at the end will remove the lowest bit anyway

        # b is even ? a * b = (2 * a) * (b / 2)
        a <<= 1
        if a >= modulus:
            a -= modulus

        # next bit
        b >>= 1

    return result


# noinspection DuplicatedCode
def pow_mod(base: np.uint32, exp: np.uint32, modulus: np.uint32) -> np.uint32:
    res = np.uint32(1)

    while exp > 0:
        # If y is odd, multiply x with result.
        if exp & 1:
            res = mul_mod(res, base, modulus)

        base = mul_mod(base, base, modulus)
        # exp must be even now.
        exp >>= 1  # y /= 2

    return res


def main():
    p1 = pow_mod(np.uint32(5), np.uint32(1466838298), np.uint32(0x71d0d8bf))
    p2 = pow_mod(np.uint32(5), np.uint32(1564871020), np.uint32(0x71d0d8bf))
    p3 = pow_mod(np.uint32(5), np.uint32(532548187), np.uint32(0x71d0d8bf))
    p4 = pow_mod(np.uint32(5), np.uint32(1970507325), np.uint32(0x71d0d8bf))
    # p1 = pow_mod(np.uint32(5), np.uint32(1), np.uint32(0x71d0d8bf))
    # p2 = pow_mod(np.uint32(5), np.uint32(2), np.uint32(0x71d0d8bf))
    # p3 = pow_mod(np.uint32(5), np.uint32(3), np.uint32(0x71d0d8bf))
    # p4 = pow_mod(np.uint32(5), np.uint32(4), np.uint32(0x71d0d8bf))
    # p1 = pow_mod(5, 1, 0x71d0d8bf)
    # p2 = pow_mod(5, 2, 0x71d0d8bf)
    # p3 = pow_mod(5, 3, 0x71d0d8bf)
    # p4 = pow_mod(5, 4, 0x71d0d8bf)
    print(p1)
    print(p2)
    print(p3)
    print(p4)

    print(pow_mod(np.uint32(0x264E0000), p1, np.uint32(0x71d0d8bf)))
    print(pow_mod(np.uint32(0x00001391), p2, np.uint32(0x71d0d8bf)))
    print(pow_mod(np.uint32(0x66310000), p3, np.uint32(0x71d0d8bf)))
    print(pow_mod(np.uint32(0x000066F0), p4, np.uint32(0x71d0d8bf)))
    # print(pow_mod(np.uint32(1), p1, np.uint32(0x71d0d8bf)))
    # print(pow_mod(np.uint32(2), p2, np.uint32(0x71d0d8bf)))
    # print(pow_mod(np.uint32(3), p3, np.uint32(0x71d0d8bf)))
    # print(pow_mod(np.uint32(4), p4, np.uint32(0x71d0d8bf)))
    # print(pow_mod(1, p1, 0x71d0d8bf))
    # print(pow_mod(2, p2, 0x71d0d8bf))
    # print(pow_mod(3, p3, 0x71d0d8bf))
    # print(pow_mod(4, p4, 0x71d0d8bf))

    u32_max = np.iinfo(np.uint32).max
    print(pow_mod(np.uint32(4564564), u32_max, u32_max))
    print(pow_mod(np.uint32(5), u32_max, u32_max))
    print(pow_mod(np.uint32(1), u32_max, u32_max))
    print(pow_mod(np.uint32(7), u32_max, u32_max))
    print(pow_mod(np.uint32(0), u32_max, u32_max))


if __name__ == "__main__":
    main()
