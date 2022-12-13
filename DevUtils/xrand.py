import numpy as np
from PIL import Image

XRAND_SEED = np.uint32(0)


def rand_u32() -> np.uint32:
    return np.uint32(np.random.randint(0, 2 ** 32 - 1, dtype=np.uint32))


# Based on glibc.
def _xrand() -> np.uint32:
    global XRAND_SEED

    # Glibc uses this algorithm when initial state is 8 bytes.
    if XRAND_SEED == 0:
        XRAND_SEED = rand_u32()

    # val = ((state * 1103515245) + 12345) & 0x7fffffff

    XRAND_SEED = ((XRAND_SEED * np.uint32(1103515245)) +
                  np.uint32(12345)) & 0x7fffffff
    return XRAND_SEED


def shuffle(x: np.uint32) -> np.uint32:
    t = (x ^ (np.right_shift(x, np.uint32(8)))) & _xrand()
    x = x ^ t ^ (np.left_shift(t, np.uint32(8)))
    t = (x ^ (np.right_shift(x, np.uint32(4)))) & _xrand()
    x = x ^ t ^ (np.left_shift(t, np.uint32(4)))
    t = (x ^ (np.right_shift(x, np.uint32(2)))) & _xrand()
    x = x ^ t ^ (np.left_shift(t, np.uint32(2)))
    t = (x ^ (np.right_shift(x, np.uint32(1)))) & _xrand()
    return np.uint32(x ^ t ^ np.left_shift(t, np.uint32(1)))


def xrand() -> int:
    return shuffle(rand_u32())


# Some visual randomness tests.
def main():
    for _ in range(10):
        test = rand_u32()
        test_s = int(shuffle(test))
        print(hex(test), hex(test_s))
        print(int(test).bit_length(), test_s.bit_length())
        print("...")

    zz = 0
    a = np.zeros((100, 100), dtype=np.uint8)
    for x in range(100):
        for z in range(25):
            r = xrand()
            a[zz][x] = r & 0xff
            a[zz + 1][x] = (r >> 8) & 0xff
            a[zz + 2][x] = (r >> 16) & 0xff
            a[zz + 3][x] = (r >> 24) & 0xff
            zz = z * 4

    im = Image.fromarray(a).convert("L")
    im.save("python_random.png")
    im.show()

    b = np.zeros((100, 100), dtype=np.uint8)
    with open("rand.txt", mode="r", encoding="utf-8") as f:
        for i, line in enumerate(f):
            data = line.strip()
            if data:
                b[i] = np.fromstring(data, sep=",")

    im_uscript = Image.fromarray(b).convert("L")
    im_uscript.save("uscript_random.png")
    im_uscript.show()


if __name__ == "__main__":
    main()
