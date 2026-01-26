import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("969582f200d7d9688a116b85a4a2492ded0eb7c40795f211d2c17510febfa83af595395b30296bee9b9bc3091bbe35dc0fcf27a1ddc220b141dc7561e2be21197ae43f6861f0861b3bd8269a75908a8f1db481e3137e9a3650385b8f427f28c1");
const vk_alpha_1: Slice = rawSlice("b7833a755bfa38602f2642b8bc4947cb902740e9bc57f3ced7e90859de7247e3dbc92b9f738ba62b59b621e5d01927ca");
const vk_beta_2 : Slice = rawSlice("940a908de1fd352cc7e537c081fef58080f83bae059e8f4e2c2c07db46b4cf8e5acbbbc07cd74483623251b7103a11cc13c8c57537e4c1a517203a592331420110b19a4094603539bfdb6ffdf241a633fc84897df0c94eb4dc5bd8011249cd55");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("97f2ad93d2608a5b8b992e49f371f347f5bb1edfae443ea8eeb6dda75a9fa91a719a5a59fd296ef11076d29f2a2e4a15");
const IC1: Slice = rawSlice("96132f2bf1197f93b0ba0be4adc07ffbf7e3c43af688032790b441a677aa1dca8752bfc7c78b30d44361c84f64dec646");
const IC2: Slice = rawSlice("a823b26509c9eb2d4ba406a5e6ca859768796c892ce08b0d9d619e768d6b7dcd30ab365268bed9a04880588c832ad7e8");
const IC3: Slice = rawSlice("8b8ad2172088f0ef3918372074127126b5902a424eee85aada0cc9b22861c2c48214a46bf0f2d15bac979a2581c0bc36");
const IC4: Slice = rawSlice("af9d48bbd3a7e2a8dd0b13bb28f0d426c3d48ab582f905bbb8fc8f215cf0044dcb47f3ddf18f69fe613bddf3a6437476");

// Message definition
message (0x3b3cca17) Verify {
  piA: Slice;
  piB: Slice;
  piC: Slice;
  pubInputs: map<Int as uint32, Int as uint256>;
}

contract Verifier with Deployable {

  receive(msg: Verify) {
    let res = self.groth16Verify(msg.piA, msg.piB, msg.piC, msg.pubInputs);
    nativeThrowUnless(ERR_WRONG_PROOF, res);
  }

  fun groth16Verify(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint256>
  ): Bool {

    // --- acc = Σ(v_i * IC_{i+1}) (ONLY public-dependent part) ---
    let haveAcc: Bool = false;
    let acc: Slice = IC0; // placeholder until haveAcc=true

    // Single batch (no loop and no ic())
    acc = blsG1Multiexp_4(
      IC1, getPub(pubInputs, 0),
      IC2, getPub(pubInputs, 1),
      IC3, getPub(pubInputs, 2),
      IC4, getPub(pubInputs, 3)
      , 4
    );
    haveAcc = true;

    // Cheap guard: reject obvious extras
    nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(4));


    // --- cpub = IC0 + acc (IC0 is added exactly once) ---
    let cpub: Slice = haveAcc ? blsG1Add(acc, IC0) : IC0;

    // Pairing check
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
    pubInputs: map<Int as uint32, Int as uint256>
  ): Bool {
    return self.groth16Verify(piA, piB, piC, pubInputs);
  }
}
