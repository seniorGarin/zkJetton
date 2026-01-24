import "../common/utils";

const vk_gamma_2_transfer: Slice = rawSlice("93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8");
const vk_delta_2_transfer: Slice = rawSlice("b898de4384f43d5554d36bdc7df88c4a643e9beb25658f3d15d12c48ec73b4053f43a97da8af4f3e738daaf94009016d08aaf52eb18349d9c569dafd31e74e188cdc0954f9d6b9fcffabfd3a52472a95e488a07d0edd569eded41f57c26f0bc6");
const vk_alpha_1_transfer: Slice = rawSlice("a48808548c0b83742a15d1a908e4952b5c519f780dbedbe3bb0ed836cf987c69c984af40098ae947e2c53021dd7a4514");
const vk_beta_2_transfer: Slice = rawSlice("815fb90dfbeb18409011a7af7d8ffd83196adffa274956c22cf958c7941cafc16e7ce1e23adb3615e4340b0f093f86de039ff4ce0636be35c3cd73604bba4418829725c5af44774569dc84e08b1fcceace325c062d963aac7e7c1eea21bafefb");

const IC0_transfer: Slice = rawSlice("ac6e48ccf5cd9984485f211bac5c09d6af93a1e598ebbfe8f05a373b26a115e99a603a04876197f7af62eff534dde83f");
const IC1_transfer: Slice = rawSlice("985be4c3ce7555152209a9683640567a5b1675200e194c625012b04c6d2dc881d7bdc7bc349903825cda8f3c05b11594");
const IC2_transfer: Slice = rawSlice("b89bbea20b4dd19b56e0b382288577c43c8f43449673815bd58e6e7b4aacf918b6221d3985a3a8f787f3889ab82da8ac");
const IC3_transfer: Slice = rawSlice("b7f1f249614e089418f57feb3bbe6840ea48ec6ebfbcf657ba3e3abed0bbac98f334728ba8cfd532fe2fa8fad6826923");

trait VerifierTransfer {
    fun groth16Verify_transfer(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint224>
    ): Bool {
        // --- acc = Σ(v_i * IC_{i+1}) ---
        let acc: Slice = blsG1Multiexp_3(
        IC1_transfer, getPub(pubInputs, 0),
        IC2_transfer, getPub(pubInputs, 1),
        IC3_transfer, getPub(pubInputs, 2),
        3
        );

        // Reject extras
        nativeThrowIf(ERR_TOO_MANY_PUBLICS, pubInputs.exists(3));

        // cpub = IC0 + acc
        let cpub: Slice = blsG1Add(acc, IC0_transfer);

        // Pairing check (ТОЧНО ИЗ TransferVerifier.tact)
        let piANeg: Slice = blsG1Neg(piA);
        let ok: Int = blsPairing(
        cpub,          vk_gamma_2_transfer,
        piANeg,        piB,
        piC,           vk_delta_2_transfer,
        vk_alpha_1_transfer, vk_beta_2_transfer,
        4
        );
        return ok != 0;
    }

    get fun verify_transfer(
    piA: Slice,
    piB: Slice,
    piC: Slice,
    pubInputs: map<Int as uint32, Int as uint224>
    ): Bool {
        return self.groth16Verify_transfer(piA, piB, piC, pubInputs);
    }
}
