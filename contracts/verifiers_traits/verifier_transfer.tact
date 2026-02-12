import "../common/utils";

const vk_gamma_2_transfer: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2_transfer: Slice = rawSlice("b8d534aa55d83ef0f321998853fc5b6877a7f851292641259a793365ffddb628544d40ea44cfb2fcf53c68e18dc06492034df5c746fe07c8b58a886d05f63024bd69047bd8a26d6d91ff32805f0ed372885d19d8c6a83900fa70d24c927383dd");
const vk_alpha_1_transfer: Slice = rawSlice("ac8cf2719f8c259c6e4d20b826c2b1b5154069a42206cffda040105cab075d1696808f47f32d6c9267754783da9ac5b2");
const vk_beta_2_transfer: Slice = rawSlice("8e5602008ddb88eec3f9031044761aa441c73c9d55ec3b0f985005e7cac4eec0ebbf1451d418eba7f39a100d36f7171c0aa2ea745421a78499fea6d077ea388599ea7e71700d11d207d47f43ca96317d6f2405fc6c19d357801c76766f346c61");

const IC0_transfer: Slice = rawSlice("93c33dc198e7902e29c96595c1a5d25118895dc494c1c71dc2d38657b44adfd4ea6cec35dd24dff8b0609795cde7d09a");
const IC1_transfer: Slice = rawSlice("83bde4e3c8fc7e1ed7a963bc0f6de286781d791dc8b389e62f18998e2fb31c09945a3a15698fdee7908a1a4dacbee65a");
const IC2_transfer: Slice = rawSlice("8bd52331e0e20d4d6f5de2ced391c401684e9dae078eb7c1ba7836bd8bd196d9ee68f2c0921ef4f1dfb1979f7d0e076a");
const IC3_transfer: Slice = rawSlice("96726499b3eec9f963b2ef9df5dd5e426db01b848cba7711b751460225b5f85675a0d83010f53ee94b2f05cdbd2eb849");
const IC4_transfer: Slice = rawSlice("b3cb6fe8a10cb42d5065cd47425c1f48f1e76c54c5bd6dfccdf90ab7b9d99e4aa0dbd75cd3bbcec9dc29b80db9ce8168");

trait VerifierTransfer {
    fun groth16Verify_transfer(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint256>
    ): Bool {
        // --- acc = Σ(v_i * IC_{i+1}) (ONLY public-dependent part) ---
        let haveAcc: Bool = false;
        let acc: Slice = IC0_transfer; // placeholder until haveAcc=true

        // Single batch (no loop and no ic())
        acc = blsG1Multiexp_4(
        IC1_transfer, getPub(pubInputs, 0),
        IC2_transfer, getPub(pubInputs, 1),
        IC3_transfer, getPub(pubInputs, 2),
        IC4_transfer, getPub(pubInputs, 3)
        , 4
        );
        haveAcc = true;

        // Cheap guard: reject obvious extras
        nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(4));


        // --- cpub = IC0 + acc (IC0 is added exactly once) ---
        let cpub: Slice = haveAcc ? blsG1Add(acc, IC0_transfer) : IC0_transfer;

        // Pairing check
        let piANeg: Slice = blsG1Neg(piA);
        let ok: Int = blsPairing(
        cpub,       vk_gamma_2_transfer,
        piANeg,     piB,
        piC,        vk_delta_2_transfer,
        vk_alpha_1_transfer, vk_beta_2_transfer,
        4
        );

        return ok != 0;
    }

    get fun verify_transfer(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint256>
    ): Bool {
        return self.groth16Verify_transfer(piA, piB, piC, pubInputs);
    }
}
