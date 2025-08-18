import "../common/utils";
// Verification key constants
const
    vk_gamma_2_transfer: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8"
    );

const
    vk_delta_2_transfer: Slice = rawSlice("ac808d62add232b4627dd3cdf52a6a51bd7e39a323f809e9dfb5389f8597939e89e08b36a6f1e4b4d0dc94321f261f100e7c781ae42be2d0d553d5f93f0208fcf3c27ea6f134a3e7191708666e0d128103171fa59b1739cc416e63b7c4576bb0"
    );

const
    vk_alpha_1_transfer: Slice = rawSlice("ada5cbab0e209815a9b248e475bb41be1b742cf5f8ea01de5688f1861926557d4cfaa7d61d25c8127b3e0b10fdf53335"
    );

const
    vk_beta_2_transfer: Slice = rawSlice("ad746f6572c7e5525f46b89354da9bfc43d0a1bcf1985cfc9d623ad4cb564ceb15187a8f530f329b1e00ffd22f389511114870a8fbdf1d3000d82dd048279530c31b683e7be7edd4f719571cc10e6a1546f2d7c16c9e40c6d8b486802ad76f8a"
    );

// IC constants (IC0_transfer — constant term)
const
    IC0_transfer: Slice = rawSlice("91bae4fff89d9f6f043082f2aee5c3a6b535b465d5efc7535e2998f291c5751305b60ebcd302925562f6d36306bb41ba"
    );

const
    IC1_transfer: Slice = rawSlice("85ab52f990dadaf3a62a3522d0463d4ff56616dec3e9e40354a1005a270435a4fc7f5573845000d15d557c320483e99a"
    );

const
    IC2_transfer: Slice = rawSlice("b4df2215acf1378f681fa000715e4bba5336de9e6bbc2db9d98768679fb65ce908e8174bbcc6bedb845cf9386f70e5bf"
    );

const
    IC3_transfer: Slice = rawSlice("b777c9d0d2dc007ba9f0d6e288153e8ac66e763edcc4d5f47edea207644431bc37cac8a5540922918ec6657438dc7d83"
    );


trait VerifierTransfer {
    fun groth16Verify_transfer(piA: Slice,
        piB: Slice,
        piC: Slice,
        pubInputs: map<Int as uint32, Int as uint224>): Bool {
        // Single batch (no loop and no ic())
        let cpub: Slice = blsG1Multiexp_3(IC1_transfer,
            pubInputs.get(0)!!,
            IC2_transfer,
            pubInputs.get(1)!!,
            IC3_transfer,
            pubInputs.get(2)!!,
            3
        );
        // Add the constant term
        cpub = blsG1Add(cpub, IC0_transfer);
        // Check that no extra public inputs exist
        nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(3));
        // Perform pairing check
        let piANeg: Slice = blsG1Neg(piA);
        let ok: Int = blsPairing(cpub,
            vk_gamma_2_transfer,
            piANeg,
            piB,
            piC,
            vk_delta_2_transfer,
            vk_alpha_1_transfer,
            vk_beta_2_transfer,
            4
        );
        return ok != 0;
    }

    get fun verify_transfer(piA: Slice, piB: Slice, piC: Slice, pubInputs: map<Int as uint32, Int as uint224>): Bool {
        return self.groth16Verify_transfer(piA, piB, piC, pubInputs);
    }
}