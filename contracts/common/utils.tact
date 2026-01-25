// Sizes
const P1_SIZE: Int = 48 * 8;
const P2_SIZE: Int = 96 * 8;

// Error codes
const ERR_PUBLIC_NOT_PRESENT: Int = 257;
const ERR_TOO_MANY_PUBLICS: Int = 258;
const ERR_INDEX_OUT_OF_RANGE: Int = 259;
const ERR_WRONG_PROOF: Int = 260;

// Safe getter for public inputs
fun getPub(pubInputs: map<Int as uint32, Int as uint224>, k: Int): Int {
  let v = pubInputs.get(k);
  if (v == null) {
    nativeThrow(ERR_PUBLIC_NOT_PRESENT);
  }
  return v!!;
}

// ASM intrinsics
asm fun blsG1Add(x: Slice, y: Slice): Slice { BLS_G1_ADD }

asm fun blsG1Neg(x: Slice): Slice { BLS_G1_NEG }

asm fun blsPairing(
  x1: Slice, y1: Slice,
  x2: Slice, y2: Slice,
  x3: Slice, y3: Slice,
  x4: Slice, y4: Slice,
  n: Int
): Int { BLS_PAIRING }

asm fun blsG1Multiexp_1(
  x1: Slice, y1: Int
  , n: Int
): Slice { BLS_G1_MULTIEXP }

asm fun blsG1Multiexp_3(
  x1: Slice, y1: Int,
  x2: Slice, y2: Int,
  x3: Slice, y3: Int
  , n: Int
): Slice { BLS_G1_MULTIEXP }


asm fun blsG1Multiexp_4(
  x1: Slice, y1: Int,
  x2: Slice, y2: Int,
  x3: Slice, y3: Int,
  x4: Slice, y4: Int
  , n: Int
): Slice { BLS_G1_MULTIEXP }

// Math
fun modInverse(a: Int, m: Int): Int {
  let a0 = a % m;
  require(a0 != 0, "modInverse: zero");

  let t: Int = 0;
  let newT: Int = 1;
  let r: Int = m;
  let newR: Int = a0;

  while (newR != 0) {
    let q: Int = r / newR;

    let tmpT: Int = t - q * newT;
    t = newT;
    newT = tmpT;

    let tmpR: Int = r - q * newR;
    r = newR;
    newR = tmpR;
  }

  require(r == 1, "modInverse: no inverse");

  if (t < 0) {
    t = t + m;
  }

  return t;
}
