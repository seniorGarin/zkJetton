import "@stdlib/deploy";

import "../common/utils";

// Verification key constants
const vk_gamma_2: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2: Slice = rawSlice("95234a6eb2569d8504f54fa9c1e21928be51b167de98ceb6ca0bb7c079a15c30ecb1ba768a1bb40ff055207e8bdf347e18429e1b57f4c9aebe0d01fe1613d87c7c71ffe084682cff8278b78fc691e6d2f5865eeec6c8895ad967e7e65631c15c");
const vk_alpha_1: Slice = rawSlice("93b848bdffe00fc339b2b2163ed9cd2465a446b680e1b29996e7e0abab7a3b217c9cf0686e89967556002719386a5ddc");
const vk_beta_2 : Slice = rawSlice("8256ef740229ee0ad49b4868d9a3f1f46dd66941e6a83b31151811a5efcf3c44c95e327c712bd8a4f716855fd540095b141aacf6943ebaeb5e4de2c66eb021bd96c1ecdbc8b941e9d4b64e0099aae1f65d32912d4d3622c8d265a23c48dfa1bb");

// IC constants (IC0 — constant term)
const IC0: Slice = rawSlice("b5388d16298ea2457df694af6385a4fc9619675fab543d17a57e59262223722dc01b7a0ed36ee46527e84188f54a8c60");
const IC1: Slice = rawSlice("a01e52440ae1fbf57320fffb796beb002575c446b3985f93f9b3f17aa92888b6a6afe3741407cc52246a72aef0cf9936");
const IC2: Slice = rawSlice("a1a360755bf89f028ba1248d7750b163d9a9a4d17feed3417cbd561269ffd6fa0b098de9f80c2d4b6dd0e0cc7310a919");
const IC3: Slice = rawSlice("93c0074323e1839506115f04205654522f49bf8197ccbeb99b8cc5afd9f12d69a0c18347f580b14deabd515df86c20b2");
const IC4: Slice = rawSlice("872217164d05b09bfaaae5bde742521324d674a11dcd11cb4ee8565493d72a49b7f358cd3789a4249f27c1425d796d8a");
const IC5: Slice = rawSlice("b060518f39c40c082a4b6a2fbbef62dbccbe36fc687d264800163189ce067a4f162bc79771ac98819042d64f09095a01");

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
