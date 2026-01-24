import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("96808edf19fd6f55d9ce0dcc77036abd2bbb52dbcefcacdb1f878a50d0493230a77961d0c2694a18ba4c4dedd71f71210d8eeda551e5d934d0ac625f2444ba121e712c86944a3fd1cea4aa0327ff753ed91c1e74ecf00c3fcce6f56500399cbd");
const vk_alpha_1: Slice = rawSlice("8a7cbfaf20af8da8436c9331b1c6cedebaca581d4596040424c75e41db40a4a710f7113a6624958faf61f86e89cece6e");
const vk_beta_2 : Slice = rawSlice("87b24c44db7ab541d53c0655fbb6d6d583a828730ec3661521b502aa0c1606c3f42ade0901adacbdf8d389b3ed9f7d1e092042f35a9383b798ba9c1c1b0d1f62f3e734e15bd6e7685eee325d8394496000a99c397ac9358a23168689bb8046a6");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("8bfa43d728fd0420ddd0ed423a6f4e90404d5c5ca1aa68f552284cd1a8dbc25d2d291addf95e116c3499587b49c28b2f");
const IC1: Slice = rawSlice("b368cdf3f3dd69636a0baf07f1e76f7613b108193c4ed7522c5409a8fe5ed683b0bfcf6fd1f51fca22f75290b42552a4");

// Message definition
message (0x3b3cca17) Verify {
  piA: Slice;
  piB: Slice;
  piC: Slice;
  pubInputs: map<Int as uint32, Int as uint224>;
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
    pubInputs: map<Int as uint32, Int as uint224>
  ): Bool {

    // --- acc = Σ(v_i * IC_{i+1}) (ONLY public-dependent part) ---
    let haveAcc: Bool = false;
    let acc: Slice = IC0; // placeholder until haveAcc=true

    // Single batch (no loop and no ic())
    acc = blsG1Multiexp_1(
      IC1, getPub(pubInputs, 0)
      , 1
    );
    haveAcc = true;

    // Cheap guard: reject obvious extras
    nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(1));


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
    pubInputs: map<Int as uint32, Int as uint224>
  ): Bool {
    return self.groth16Verify(piA, piB, piC, pubInputs);
  }
}
