import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("b753c993ab8fb8b2ccf549b3b693653a4a82df7e668541a5eb856083f522e3bcfe47422f11de42c4656e1df3d2028bd2133de51bd413e49216bd792880fba68ed33e7c1333b626acab8bc89fbc957c11348ffa417517be880922e1b048334a5b");
const vk_alpha_1: Slice = rawSlice("b4d02b4745438e2640324c7edfb7d38318585e00a9570c6635fc06faa2dbeee65a73664922633682c8409980f9654e60");
const vk_beta_2 : Slice = rawSlice("a1d40e23a504e2ea3d4600765ec1af9cc5251871bf877f05e84e2ff4033cd15711cb72bf875921ef8e6eb1b2d53567b21436c8dd39b9afdeaac7a3d603e75153705a899dc10fcd3e08c0f39b23f363b0a83882f985fd10a7972d0b323dd11fcb");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("a0cd9971e048219fd9a6bbd011d2de36e24ea73d57bbdbbb9dc24f4291ddcad10bfc0b81a85d70203283607d0ad92265");
const IC1: Slice = rawSlice("821b05a46f903dcc9595016cfefd3866b63d09221bc723723dbeedd539f98e06af56091d8ae12bc9a1bed7a3a9b1984a");
const IC2: Slice = rawSlice("950c0c9007bdd92f264f36489312b5f53acf60064014173ebacdac53ede4c311e272af063da3b0d68a8ac908bb018a39");
const IC3: Slice = rawSlice("ac2ad0368ea10d4f355272829eb9d7389c76bf09ce0e704b1081fd588179752a72898ba57a1b871526c057f222edcdc3");
const IC4: Slice = rawSlice("b2ff6ba8453a6fda1b0e2fffeac73e7770dedd73965544e6ecb0fedeb0c8721a0db3bc947a8a523a1ddbdac0c3d4452c");

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
    pubInputs: map<Int as uint32, Int as uint224>
  ): Bool {
    return self.groth16Verify(piA, piB, piC, pubInputs);
  }
}
