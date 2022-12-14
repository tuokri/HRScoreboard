import sys

import numba as nb
import numpy as np
import numpy.typing as npt


@nb.njit(nb.boolean(nb.int32), cache=True)
def naive_is_prime(n: np.int32) -> bool:
    if n == 2:
        return True
    if n < 2 or n % 2 == 0:
        return False
    return np.array([
        n % i != 0
        for i in np.arange(3, np.int32(n ** 0.5 + 1), 2)
    ]).all()


@nb.njit(nb.int32(nb.int32, nb.int32, nb.int32), cache=True)
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


@nb.njit(nb.int32(nb.int32, nb.int32, nb.int32), cache=True)
def pow_mod(base: np.int32, exp: np.int32, modulus: np.int32) -> np.int32:
    res = np.uint32(1)

    while exp > 0:
        # If y is odd, multiply x with result.
        if exp & 1:
            res = mul_mod(res, base, modulus)

        base = mul_mod(base, base, modulus)
        # exp must be even now.
        exp >>= 1  # y /= 2

    return res


@nb.njit(nb.int32(nb.int32, nb.int32, nb.int32[:]), cache=True)
def get_order(
        r: np.int32,
        n: np.int32,
        euler_func_divisors: npt.NDArray[np.int32],
) -> np.int32:
    """Calculate the order of a number, the minimal power
    at which r would be congruent with 1 by modulo p.
    """
    r %= n
    for d in euler_func_divisors:
        if pow_mod(r, d, n) == 1:
            return d

    # No such order, not possible if n is prime.
    # See small Fermat's theorem.
    return np.int32(0)


@nb.njit(nb.boolean(nb.int32, nb.int32, nb.int32[:], nb.int32), cache=True)
def is_primitive_root(
        r: np.int32,
        n: np.int32,
        euler_func_divisors: npt.NDArray[np.int32],
        euler_func: np.int32,
) -> bool:
    """Check if r is a primitive root by modulo p.
    Such always exists if p is prime.
    """
    return get_order(
        r=r,
        n=n,
        euler_func_divisors=euler_func_divisors,
    ) == euler_func


@nb.njit(nb.int32[:](nb.int32, nb.int32), cache=True, parallel=True)
def find_all_primitive_roots(
        sophie_germain_prime: np.int32,
        limit: np.int32 = 0,
) -> npt.NDArray[np.int32]:
    n = (np.int32(2) * sophie_germain_prime) + np.int32(1)

    if not naive_is_prime(n):
        raise RuntimeError("n is not a prime")
    if not naive_is_prime(sophie_germain_prime):
        raise RuntimeError("input is not a prime")

    euler_func = n - np.int32(1)
    euler_func_divisors = np.array(
        [1, 2, sophie_germain_prime, euler_func],
        dtype=np.int32)

    # print("n =", n)
    # print("euler_func =", euler_func)
    # print("euler_func_divisors =", euler_func_divisors)

    if limit > 0:
        roots = np.zeros(limit, dtype=np.int32)
        i = 0
        for g in np.arange(np.int32(1), n):
            if is_primitive_root(
                    r=g,
                    n=n,
                    euler_func_divisors=euler_func_divisors,
                    euler_func=euler_func,
            ):
                roots[i] = g
                i += 1
                if i >= limit:
                    return roots
        return roots
    else:
        return np.array([
            g for g in np.arange(np.int32(1), n)
            if is_primitive_root(
                r=g,
                n=n,
                euler_func_divisors=euler_func_divisors,
                euler_func=euler_func,
            )
        ], dtype=np.int32)


def main():
    sophie_germain_prime = np.int32(sys.argv[1])
    try:
        limit = np.int32(sys.argv[2])
    except IndexError:
        limit = np.int32(0)
        raise

    print(find_all_primitive_roots(sophie_germain_prime, limit))

    p = np.int32(0x71d0d8bf)
    g = np.int32(5)
    a1 = np.int32(535923286)
    a2 = np.int32(454433934)
    a3 = np.int32(1729154768)
    a4 = np.int32(1263081226)

    print("...")
    priv1 = np.int32(0x264E0000)
    priv2 = np.int32(0x00001391)
    priv3 = np.int32(0x66310000)
    priv4 = np.int32(0x000066F0)
    print(priv1)
    print(priv2)
    print(priv3)
    print(priv4)
    print("...")

    pub1 = pow_mod(g, a1, p)
    pub2 = pow_mod(g, a2, p)
    pub3 = pow_mod(g, a3, p)
    pub4 = pow_mod(g, a4, p)
    print(pub1)
    print(pub2)
    print(pub3)
    print(pub4)

    print("...")
    pubx1 = pow_mod(g, priv1, p)
    pubx2 = pow_mod(g, priv2, p)
    pubx3 = pow_mod(g, priv3, p)
    pubx4 = pow_mod(g, priv4, p)
    print(pubx1)
    print(pubx2)
    print(pubx3)
    print(pubx4)

    shared1 = pow_mod(pubx1, a1, p)
    shared2 = pow_mod(pubx2, a2, p)
    shared3 = pow_mod(pubx3, a3, p)
    shared4 = pow_mod(pubx4, a4, p)
    sharedx1 = pow_mod(pub1, priv1, p)
    sharedx2 = pow_mod(pub2, priv2, p)
    sharedx3 = pow_mod(pub3, priv3, p)
    sharedx4 = pow_mod(pub4, priv4, p)

    print("...")
    print(shared1)
    print(shared3)
    print(shared2)
    print(shared4)
    print("...")
    print(sharedx1)
    print(sharedx3)
    print(sharedx2)
    print(sharedx4)

    print("###")
    print(pow_mod(2568421697, 358644730, 1909512383))


if __name__ == "__main__":
    main()
