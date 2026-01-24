import "../common/utils";

const vk_gamma_2_registration: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2_registration: Slice = rawSlice("ae5fe338e3d0a7a1dab77a32b722f0bd7cc0fe0aab7534306006bdf2d6a00c5ae7e2ba05d12adde515291f110da164380fa9b3d4489314629a8629c497e02e3ce27e6e51cb9bfab923fda5f1af7a759b07889d8d68ef59d488e5fcdf317cdf9a");
const vk_alpha_1_registration: Slice = rawSlice("85881a93e59021f4808ee2735a329bed9da96293db449ffa86542ad49aef8973ceace02da3f1897bd7279b1cab4f9901");
const vk_beta_2_registration: Slice = rawSlice("96bb516048601d24c6fb999eb4746181f10faa794c6229b05acd2d88048366a86769b6249e40f3331ee6c360b08bca561582f593626cd740dcb50c4b9dc6b320fa32294e9f11e26657073a3b026a321ab18e5872e352e576035a0ccc657aa127");

const IC0_registration: Slice = rawSlice("86757734f9c70839e5b05e4520426ddea0ea2394cd9931124c82e5517af6281b90b15e9e7acf1fb9bf4a2c0784482a0a");
const IC1_registration: Slice = rawSlice("810d652636cdc8fd1bd846db6d73d42196679119d7cca9e205330e099770153f4be46322bcc3ea344738815d784bbf65");
const IC2_registration: Slice = rawSlice("a1c26bd1737359050e38bd46a3ec6d1ce4a52e7b8adbb577ac31c3afe70dcedbc7c7cd260c8944a5e16142431dac8708");
const IC3_registration: Slice = rawSlice("a162537bb6427374add80d99baac385e3762c885582de02c58539f0264f42710dd355ef67675efa81d73b0a88638b58d");
const IC4_registration: Slice = rawSlice("91bf68a3fca3f46a63934828d7f37e52c272a3d1c1e371e6273991b01499f74dbfd9da04d46f6873e7907005eec3f906");

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
        cpub,          vk_gamma_2_registration,
        piANeg,        piB,
        piC,           vk_delta_2_registration,
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
