import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("82b99120b5bc38b02838e7d0a059ad6235bc64252d2fb03c4b5e71a270dd33aecef64855d5545efdfabd577e633c7e3f0ead08a36824460c8920916396f9624a151edd52d9a8a3bee344b6b7d7a1bd6d915d0c79e8cb305478edc6ffc04770dc");
const vk_alpha_1: Slice = rawSlice("af9a02795bc3ff0b49c92b9f263f0e63816ca1cbf87dfeea4ea77c01656d5e94a804d9d2625de209a482e23d0ddf7c80");
const vk_beta_2 : Slice = rawSlice("9452b782dbd63ec2763422b786934aca29effcac16d17e634bee09b10ea0da38b0d9e1a7b961c81264a0b6e2986475930bdccb427b5a3f10d932b1ac7ef87f5c6592b57c8df7e1e3491834f0249b7960bd23103b693f6ae603a4cb2019fedd62");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("a027790cbad9ed2b1e7aa37777fb297eaee2b4ce6113091ceea0a020421188dd779c146a2c325eaf67c0e988fe9517b9");
const IC1: Slice = rawSlice("b8ab659a31c067ccdb00ac76899acab37a4cad98e7ce2c45f770b0b36326fdd1215ff650f596cff416091c71f37882be");
const IC2: Slice = rawSlice("81ac9ccef6d51824ef62f5f36d84828e70448c5f5e928d02862866ffb3a963114907f2dc50b13efa1b08b5ccd320a149");
const IC3: Slice = rawSlice("813b1e908420713ffcb32a6ac65bba53a98d4ce3618add9a60af24cdf8911643f3344ed73a209aa9f34d3dbf35543557");
const IC4: Slice = rawSlice("b7eac2fec7a6351a9cf45ca898adc30cd514f7226444eafb7272a8674ab874ffef97a700a0be5504660a8091ad590c2b");
const IC5: Slice = rawSlice("8c507fc77467e5012c412d8714fae6fdb45e11e6e62373cd36d3b70bd7888a18c99815b470ea7eea45719132fbeeb74e");

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
    acc = blsG1Multiexp_5(
      IC1, getPub(pubInputs, 0),
      IC2, getPub(pubInputs, 1),
      IC3, getPub(pubInputs, 2),
      IC4, getPub(pubInputs, 3),
      IC5, getPub(pubInputs, 4)
      , 5
    );
    haveAcc = true;

    // Cheap guard: reject obvious extras
    nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(5));


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
