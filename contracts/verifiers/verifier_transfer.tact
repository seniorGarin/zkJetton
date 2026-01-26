import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("985b68fe8f55f4b2f94bfe7967e8ecf39520ce21761d6b5eac18075e728c0b72f177e2be5027d0e277327ce146f0446117b3af4f7307b057e205f8f4e233eff65baa18d1059eadd6ba9b0ce86e077d9d4df077b79a95108d69da5d63c2ea08c1");
const vk_alpha_1: Slice = rawSlice("b591dc99a722a804ce162048674428118a6a72d1f0d62b3f13d7a6364370399730afe49c286efac9861c476c12d6a81b");
const vk_beta_2 : Slice = rawSlice("a3669812b3382007876278959bcdf51b0c10cb4b8bf11a345e324e91ec2c1b498f74fcb8780438c7df9176f64e2da66e0b52cdd1da07cb53615810359fc34b7b50f5abc67f52c83975f98f30e22e134c30a8a64c0a079ae90074d330538532b6");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("b1a5d575016ed2d6d24ca4d530e49f4bdf8d6cbd8a9afd276f9aeb5e64c6288518d046ea1d5964f2e85798e9f8316cd4");
const IC1: Slice = rawSlice("b9052348b8d739bb38406901ec58e4c06c62091bbc42758471fcb53cbed292c3530c33e40a038f8b8c67da1f30a6c718");
const IC2: Slice = rawSlice("999c6b2bc21382c8f9963c832d85cf289699eaa6a53f9a707b29246cd3541e9737ca0ee7b7db2750b4daa3a068f98b55");
const IC3: Slice = rawSlice("a646008d4b35ee86eb5f4098fbe9f36304550191060ecdef3908788a6a2782eb4ccc22aa29c87fb674ba47ba8a9272a7");
const IC4: Slice = rawSlice("9539c5def64aa719daf34479ab43d3fb4e43a97620e90d94f78280128380ad3ffcafd5fe40a899027620bcaacaaef02e");

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
