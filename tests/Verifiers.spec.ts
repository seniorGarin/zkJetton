import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, toNano } from '@ton/core';
import '@ton/test-utils';

import paillierBigint from 'paillier-bigint';
import { dictFromInputList, groth16CompressProof } from 'export-ton-verifier';

import { Verifier as Registration_Verifier } from '../build/verifiers/VerifierRegistration_Verifier';
import { Verifier as Mint_Verifier } from '../build/verifiers/VerifierMint_Verifier';
import { Verifier as Transfer_Verifier } from '../build/verifiers/VerifierTransfer_Verifier';

import { createMintProof, createRegistrationProof, createTransferProof } from './helpers';

// npx blueprint test Verifiers
describe('Verifiers', () => {
    let blockchain: Blockchain;
    let owner: SandboxContract<TreasuryContract>;
    let user1: SandboxContract<TreasuryContract>;
    let user2: SandboxContract<TreasuryContract>;

    let registration: SandboxContract<Registration_Verifier>;
    let mint: SandboxContract<Mint_Verifier>;
    let transfer: SandboxContract<Transfer_Verifier>;

    let keys1: paillierBigint.KeyPair;
    let keys2: paillierBigint.KeyPair;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        owner = await blockchain.treasury('owner');
        user1 = await blockchain.treasury('user1');
        user2 = await blockchain.treasury('user2');

        keys1 = await paillierBigint.generateRandomKeys(32);
        keys2 = await paillierBigint.generateRandomKeys(32);

        await deployRegistration();
        await deployMint();
        await deployTransfer();
    });

    it('Registration proof', async () => {
        const { proof, publicSignals } = await createRegistrationProof(keys1);
        const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

        expect(
            await registration.getVerify(
                beginCell().storeBuffer(pi_a).endCell().asSlice(),
                beginCell().storeBuffer(pi_b).endCell().asSlice(),
                beginCell().storeBuffer(pi_c).endCell().asSlice(),
                dictFromInputList(pubInputs),
            ),
        ).toBeTruthy();

        const verifyResult = await registration.send(
            user1.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Verify',
                piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
                piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
                piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
                pubInputs: dictFromInputList(pubInputs),
            },
        );

        expect(verifyResult.transactions).toHaveTransaction({
            from: user1.address,
            to: registration.address,
            success: true,
        });
    });

    it('Mint proof', async () => {
        const { proof, publicSignals } = await createMintProof(keys1, 1n, user1.address);
        const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

        expect(
            await mint.getVerify(
                beginCell().storeBuffer(pi_a).endCell().asSlice(),
                beginCell().storeBuffer(pi_b).endCell().asSlice(),
                beginCell().storeBuffer(pi_c).endCell().asSlice(),
                dictFromInputList(pubInputs),
            ),
        ).toBeTruthy();

        const verifyResult = await mint.send(
            user1.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Verify',
                piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
                piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
                piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
                pubInputs: dictFromInputList(pubInputs),
            },
        );

        expect(verifyResult.transactions).toHaveTransaction({
            from: user1.address,
            to: mint.address,
            success: true,
        });
    });

    it('Transfer proof', async () => {
        const { proof, publicSignals } = await createTransferProof(keys1, keys2, keys1.publicKey.encrypt(1000n), 0n);

        const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

        expect(
            await transfer.getVerify(
                beginCell().storeBuffer(pi_a).endCell().asSlice(),
                beginCell().storeBuffer(pi_b).endCell().asSlice(),
                beginCell().storeBuffer(pi_c).endCell().asSlice(),
                dictFromInputList(pubInputs),
            ),
        ).toBeTruthy();

        const verifyResult = await transfer.send(
            user1.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Verify',
                piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
                piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
                piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
                pubInputs: dictFromInputList(pubInputs),
            },
        );

        expect(verifyResult.transactions).toHaveTransaction({
            from: user1.address,
            to: transfer.address,
            success: true,
        });
    });

    async function deployRegistration() {
        registration = blockchain.openContract(await Registration_Verifier.fromInit());

        const deployResult = await registration.send(
            owner.getSender(),
            {
                value: toNano('0.05'),
            },
            { $$type: 'Deploy', queryId: 0n },
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: owner.address,
            to: registration.address,
            deploy: true,
            success: true,
        });
    }

    async function deployMint() {
        mint = blockchain.openContract(await Mint_Verifier.fromInit());

        const deployResult = await mint.send(
            owner.getSender(),
            {
                value: toNano('0.05'),
            },
            { $$type: 'Deploy', queryId: 0n },
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: owner.address,
            to: mint.address,
            deploy: true,
            success: true,
        });
    }

    async function deployTransfer() {
        transfer = blockchain.openContract(await Transfer_Verifier.fromInit());

        const deployResult = await transfer.send(
            owner.getSender(),
            {
                value: toNano('0.05'),
            },
            { $$type: 'Deploy', queryId: 0n },
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: owner.address,
            to: transfer.address,
            deploy: true,
            success: true,
        });
    }
});
