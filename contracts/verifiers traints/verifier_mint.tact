import "../common/utils";
// Verification key constants
const
    vk_gamma_2_mint: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8"
    );

const
    vk_delta_2_mint: Slice = rawSlice("98bbf3793ea3eb4bef23f5e76309676d585744e8457e9d9a74c4488aca7419967f9378d8e5eb7536acbaae9ce1101098015739192c6b152766aa0d849aa22a0dc1bd1638a3ea524318183db0b0e2aee4a86d22945ad8fdc543b9b415b0aa7562"
    );

const
    vk_alpha_1_mint: Slice = rawSlice("92fb17d1fd23efb235c736d744739b9ee640dd558d3c56b931c79f145aab60851082106002edbd2742cd3d4db4e96279"
    );

const
    vk_beta_2_mint: Slice = rawSlice("a6f244a53f64e2e287dfff636727bbf399b503364581ee62fd2ed5e466697bf7b372cb72e2d7ec8183e9d08d6bc95c41078be41010a5e2a2bece26deeab3360446fe745e674364d1cf1fac5ec857bdeca8103084ceb8f052a73e1e3de682f615"
    );

// IC constants (IC0_mint — constant term)
const
    IC0_mint: Slice = rawSlice("83a57d5cc8e2468cb114e33e6be63ef1ca52b6ed3ddfd98e08dbe4b9d71ecba3238aa87b4534cc661a0601653d2cbac1"
    );

const
    IC1_mint: Slice = rawSlice("b5473ea4f3b445f001965961166ac56868a7fd4e8fc0eac23bece60b7719e733e94503ecf749d27fef9b0841fd16bb42"
    );


trait MintVerifier {
    fun groth16Verify_mint(piA: Slice, piB: Slice, piC: Slice, pubInputs: map<Int as uint32, Int as uint224>): Bool {
        // Single batch (no loop and no ic())
        let cpub: Slice = blsG1Multiexp_1(IC1_mint, pubInputs.get(0)!!, 1);
        // Add the constant term
        cpub = blsG1Add(cpub, IC0_mint);
        // Check that no extra public inputs exist
        nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(1));
        // Perform pairing check
        let piANeg: Slice = blsG1Neg(piA);
        let ok: Int = blsPairing(cpub,
            vk_gamma_2_mint,
            piANeg,
            piB,
            piC,
            vk_delta_2_mint,
            vk_alpha_1_mint,
            vk_beta_2_mint,
            4
        );
        return ok != 0;
    }

    get fun verify_mint(piA: Slice, piB: Slice, piC: Slice, pubInputs: map<Int as uint32, Int as uint224>): Bool {
        return self.groth16Verify_mint(piA, piB, piC, pubInputs);
    }
}