import "../common/utils";

const vk_gamma_2_registration: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2_registration: Slice = rawSlice("a52212ab4f4249c5ccfbe0dd9b0c9d243eda22c3609aaf62a0ecf72309c64c683928a591a1b66a881ce13a7aef619afc0f7d818d2399b33677db1e1a7bb7469500b6e7be727d9a11d4be411687a1fac7dec0ccc6eaef36e8f30e5a3bef4fefca");
const vk_alpha_1_registration: Slice = rawSlice("b93888e7643bf4add921e7a9b81c2dbd37250abc096191ae60c5685d68953ce4f8a1aad6ca25fbe846246ffea167d03f");
const vk_beta_2_registration: Slice = rawSlice("8d1c5ab60a2fe9c58fb1e6cabf000e5c3c74088920297d290fe37711227fa89ff4d17980fc62b92ac0c5aed47e2c4c1300314a5be5c4ab77c71acf9662bda8b278272792c1c2c7f21b73ab40bae4acf1d450a8a4fef11de57c08ef3ece3086fa");

const IC0_registration: Slice = rawSlice("965c7293b8a9c826e3ead53ed43ab4947736d64b0e492f676bf8cfedc00fd44b1d00b98fba38d933508ac14ccc5078ea");
const IC1_registration: Slice = rawSlice("a64deac4cd163548193d7c691c854549b9abeb709a6be86f5268e0f1418db5394594baea71ba7a1da4c3d447ceff2bea");
const IC2_registration: Slice = rawSlice("b95fa362b928395514d769e110e419b144b7b6d07faf5cea62844d1abcd65cff5a0b005b9736a6cd65770df1f12a9493");
const IC3_registration: Slice = rawSlice("aff65da7564758d8f61a139f09cbdb01061346790340b8e4b435c8eef874faa8f900be8f944cc89f45be30c8f8d575b4");
const IC4_registration: Slice = rawSlice("a1f78f76a63160855e9bed5f2734cd15f83910064cff606aefefca900ca27f863ec6a55065617bedcf4dcbc8428a919b");

trait RegistrationVerifier {
    fun groth16Verify_registration(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint224>
    ): Bool {
        // Single batch (no loop and no ic())
        let acc: Slice = blsG1Multiexp_4(
        IC1_registration, getPub(pubInputs, 0),
        IC2_registration, getPub(pubInputs, 1),
        IC3_registration, getPub(pubInputs, 2),
        IC4_registration, getPub(pubInputs, 3),
        4
        );

        // Cheap guard: reject obvious extras
        nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(4));

        // Add the constant term
        let cpub: Slice = blsG1Add(acc, IC0_registration);

        // Pairing check
        let piANeg: Slice = blsG1Neg(piA);
        let ok: Int = blsPairing(
        cpub,                    vk_gamma_2_registration,
        piANeg,                  piB,
        piC,                     vk_delta_2_registration,
        vk_alpha_1_registration, vk_beta_2_registration,
        4
        );
        return ok != 0;
    }

    get fun verify_registration(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint224>
    ): Bool {
        return self.groth16Verify_registration(piA, piB, piC, pubInputs);
    }
}
