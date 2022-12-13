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
def power(x: np.int32, y: np.int32, p: np.int32) -> np.int32:
    res = np.int32(1)
    x %= p

    while y > 0:
        # If y is odd, multiply x with result.
        if y & 1:
            res = (res * x) % p

        # y must be even now.
        y >>= 1  # y /= 2
        x = (x * x) % p

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
        if power(r, d, n) == 1:
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
        raise RuntimeError
    if not naive_is_prime(sophie_germain_prime):
        raise RuntimeError

    euler_func = n - np.int32(1)
    euler_func_divisors = np.array(
        [1, 2, sophie_germain_prime, euler_func],
        dtype=np.int32)

    print("n =", n)
    print("euler_func =", euler_func)
    print("euler_func_divisors =", euler_func_divisors)

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

    p = np.int32(1043466059)
    g = np.int32(5)
    a1 = np.int32(535923286)
    a2 = np.int32(454433934)
    a3 = np.int32(1729154768)
    a4 = np.int32(1263081226)

    print(power(g, a1, p))
    print(power(g, a2, p))
    print(power(g, a3, p))
    print(power(g, a4, p))


if __name__ == "__main__":
    main()
