import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("834dc54a93a8d0ed9d339b0b0e5c659b865df1b06999fcba9352156814d9575fa218d5ce0da1bccf40c8e454d623115518a6e2c08b0531941c2df893b098d178c0e92f2205ea1d271fb76001ca045b7079a992129569af36c31250b42d2139ee");
const vk_alpha_1: Slice = rawSlice("90648d4f1eb7ce4efe96b45a54b96dd2d7ff7f73b12fb7449da34577f5d620dc752d009804ac96f14afb7c4dcc50462a");
const vk_beta_2 : Slice = rawSlice("a81f865733704655d70d33f7abec1fecca9909040e452dbb34713fd48444c736272fbd2bfaec95a5cd7f2458cf0817a20e2f307adc2205332c8e104fab8e98f3857659b171155e22b89bff0ffdef97f44ffb79eede5893f7d8d34fb82625d07e");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("a98de3d0790aa4a7d5ffc082b1f0849c015ae58e0ef218bb7793cac431ea60f0a85ca8e3b61ff51396786a817bff055d");
const IC1: Slice = rawSlice("b8149539b0153422c3edb1c915ca1c2f9cb39c496f848450f8c13af44ac04e3424357247565ab30b4cb8e6bd105f09de");
const IC2: Slice = rawSlice("a87124fae9d05d3f945761116340279f2e91998592fae7e88c1fb024e80c694b7c55509b2903df8e20214d13487f3e04");
const IC3: Slice = rawSlice("8a9a15d1a0382b8c2b4b2ca87c2152caf37f9c3fdb7e028dfddeca55d831e6398598bc0abb700f20fa86a20eb1913d20");
const IC4: Slice = rawSlice("b7d0aca27ff603b869c1fffd994a2e0d8b9639554801d2385b8ac2189b964357d6e4e312b814033c7512f35ba4c55d04");

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
