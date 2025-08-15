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


asm fun blsG1Multiexp_3(
  x1: Slice, y1: Int,
  x2: Slice, y2: Int,
  x3: Slice, y3: Int
  , n: Int
): Slice { BLS_G1_MULTIEXP }

// Sizes
const P1_SIZE: Int = 48 * 8;
const P2_SIZE: Int = 96 * 8;

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("ac808d62add232b4627dd3cdf52a6a51bd7e39a323f809e9dfb5389f8597939e89e08b36a6f1e4b4d0dc94321f261f100e7c781ae42be2d0d553d5f93f0208fcf3c27ea6f134a3e7191708666e0d128103171fa59b1739cc416e63b7c4576bb0");
const vk_alpha_1: Slice = rawSlice("ada5cbab0e209815a9b248e475bb41be1b742cf5f8ea01de5688f1861926557d4cfaa7d61d25c8127b3e0b10fdf53335");
const vk_beta_2 : Slice = rawSlice("ad746f6572c7e5525f46b89354da9bfc43d0a1bcf1985cfc9d623ad4cb564ceb15187a8f530f329b1e00ffd22f389511114870a8fbdf1d3000d82dd048279530c31b683e7be7edd4f719571cc10e6a1546f2d7c16c9e40c6d8b486802ad76f8a");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("91bae4fff89d9f6f043082f2aee5c3a6b535b465d5efc7535e2998f291c5751305b60ebcd302925562f6d36306bb41ba");
const IC1: Slice = rawSlice("85ab52f990dadaf3a62a3522d0463d4ff56616dec3e9e40354a1005a270435a4fc7f5573845000d15d557c320483e99a");
const IC2: Slice = rawSlice("b4df2215acf1378f681fa000715e4bba5336de9e6bbc2db9d98768679fb65ce908e8174bbcc6bedb845cf9386f70e5bf");
const IC3: Slice = rawSlice("b777c9d0d2dc007ba9f0d6e288153e8ac66e763edcc4d5f47edea207644431bc37cac8a5540922918ec6657438dc7d83");

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
    let cpub: Slice = blsG1Multiexp_3(
      IC1, pubInputs.get(0)!!,
      IC2, pubInputs.get(1)!!,
      IC3, pubInputs.get(2)!!
      , 3
    );

    // Add the constant term
    cpub = blsG1Add(cpub, IC0);

    // Check that no extra public inputs exist
    nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(3));

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
