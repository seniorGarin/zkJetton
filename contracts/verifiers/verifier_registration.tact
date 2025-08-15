import "@stdlib/deploy";

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


asm fun blsG1Multiexp_4(
  x1: Slice, y1: Int,
  x2: Slice, y2: Int,
  x3: Slice, y3: Int,
  x4: Slice, y4: Int
  , n: Int
): Slice { BLS_G1_MULTIEXP }

// Sizes
const P1_SIZE: Int = 48 * 8;
const P2_SIZE: Int = 96 * 8;

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("90ee330eca383e937f532c8c9b9d60788a219dc3c826268be0cbc3b2fe0f95213bbf8f88f4fac345b81ff2d7cab1c1a9142ea42e8a390bf078c84d6222997f16b8e9fab2bb419a903c0e6eb024738956ed439af6c87d410a9452a2e10ff385c7");
const vk_alpha_1: Slice = rawSlice("b017970cde57de26516655284d088c9c5f44a8614ee21ea5e9ec8ad3101104f90c30639da96e0fa0764a440773865209");
const vk_beta_2 : Slice = rawSlice("81cbb2751010ba9b4613f1ba88fbc1ff7131980395ac9ab45133dc9be3c0e375d1dac0312681f32ed3034d490c7a46fe09d8b29db28b56b4348999691b81b38e0c8d624312fb8f562d8a4b48a738496ee6093c522582a5ca634444f70eed2a08");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("a3ba474f4dc66cd0e68e7a224fbc1f473f68f6444fa1b43592d2db4fdc9bdd22da101381d7de795420b75a63693e92d8");
const IC1: Slice = rawSlice("a2516987ffcae24972150f2b5ff494b045bdfe3dbdf95f2986bdf529edc2f9037e683c916d981dfb4bf1ad22220cad1e");
const IC2: Slice = rawSlice("80d627c2ac57fdd76b421320e1b451576a53a21b17bdc5cbe70bf5c9743dfb957bb4a88bfd74341615dc20a17c69bb6b");
const IC3: Slice = rawSlice("8fc77352d6e6d70b3ea8e6f81c95c6cac755ae1c5df9b8859111466aa5e84ae1e86148917c221f657efb80750e3ba8ae");
const IC4: Slice = rawSlice("ad0159943050c6df3438d998cf4c7c9143610c59917ebfbd6a716e5db3e13fe399db3a6111fc1e6508a45b76ad89b5fb");

// Error codes
const ERR_PUBLIC_NOT_PRESENT: Int = 257;
const ERR_TOO_MANY_PUBLICS: Int = 258;
const ERR_INDEX_OUT_OF_RANGE: Int = 259;


// Message definition
message Verify {
  piA: Slice;
  piB: Slice;
  piC: Slice;
  pubInputs: map<Int as uint32, Int>;
}

contract Verifier with Deployable {

  receive(msg: Verify) {
    let res = self.groth16Verify(msg.piA, msg.piB, msg.piC, msg.pubInputs);
  }

  fun groth16Verify(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int>
  ): Bool {
    // Single batch (no loop and no ic())
    let cpub: Slice = blsG1Multiexp_4(
      IC1, pubInputs.get(0)!!,
      IC2, pubInputs.get(1)!!,
      IC3, pubInputs.get(2)!!,
      IC4, pubInputs.get(3)!!
      , 4
    );

    // Add the constant term
    cpub = blsG1Add(cpub, IC0);

    // Check that no extra public inputs exist
    nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(4));

    // Perform pairing check
    let piANeg: Slice = blsG1Neg(piA);
    let ok: Int = blsPairing(
      cpub,       vk_gamma_2,
      piANeg,     piB,
      piC,        vk_delta_2,
      vk_alpha_1, vk_beta_2,
      4
    );
    return ok != 0;
  }

  get fun verify(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int>
  ): Bool {
    return self.groth16Verify(piA, piB, piC, pubInputs);
  }
}
