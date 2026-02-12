import "../common/utils";

const vk_gamma_2_registration: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2_registration: Slice = rawSlice("834dc54a93a8d0ed9d339b0b0e5c659b865df1b06999fcba9352156814d9575fa218d5ce0da1bccf40c8e454d623115518a6e2c08b0531941c2df893b098d178c0e92f2205ea1d271fb76001ca045b7079a992129569af36c31250b42d2139ee");
const vk_alpha_1_registration: Slice = rawSlice("90648d4f1eb7ce4efe96b45a54b96dd2d7ff7f73b12fb7449da34577f5d620dc752d009804ac96f14afb7c4dcc50462a");
const vk_beta_2_registration: Slice = rawSlice("a81f865733704655d70d33f7abec1fecca9909040e452dbb34713fd48444c736272fbd2bfaec95a5cd7f2458cf0817a20e2f307adc2205332c8e104fab8e98f3857659b171155e22b89bff0ffdef97f44ffb79eede5893f7d8d34fb82625d07e");

const IC0_registration: Slice = rawSlice("a98de3d0790aa4a7d5ffc082b1f0849c015ae58e0ef218bb7793cac431ea60f0a85ca8e3b61ff51396786a817bff055d");
const IC1_registration: Slice = rawSlice("b8149539b0153422c3edb1c915ca1c2f9cb39c496f848450f8c13af44ac04e3424357247565ab30b4cb8e6bd105f09de");
const IC2_registration: Slice = rawSlice("a87124fae9d05d3f945761116340279f2e91998592fae7e88c1fb024e80c694b7c55509b2903df8e20214d13487f3e04");
const IC3_registration: Slice = rawSlice("8a9a15d1a0382b8c2b4b2ca87c2152caf37f9c3fdb7e028dfddeca55d831e6398598bc0abb700f20fa86a20eb1913d20");
const IC4_registration: Slice = rawSlice("b7d0aca27ff603b869c1fffd994a2e0d8b9639554801d2385b8ac2189b964357d6e4e312b814033c7512f35ba4c55d04");

trait RegistrationVerifier {
    fun groth16Verify_registration(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint256>
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
    pubInputs: map<Int as uint32, Int as uint256>
    ): Bool {
        return self.groth16Verify_registration(piA, piB, piC, pubInputs);
    }
}
