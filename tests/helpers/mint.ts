import paillierBigint from 'paillier-bigint';
import * as snarkjs from 'snarkjs';
import path from 'path';

import { SandboxContract, TreasuryContract } from '@ton/sandbox';

import { getRandomBigInt, mintValue } from './common';
import { ZkJettonMinter } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonMinter';
import { beginCell, toNano } from '@ton/core';
import { dictFromInputList, groth16CompressProof } from 'export-ton-verifier';
import { ZkJettonWallet } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';

const wasmPath = path.join(__dirname, '../../circuits/mint/mint_js', 'mint.wasm');
const zkeyPath = path.join(__dirname, '../../circuits/mint', 'mint_final.zkey');

export async function mint(
    keys: paillierBigint.KeyPair,
    owner: SandboxContract<TreasuryContract>,
    user: SandboxContract<TreasuryContract>,
    zkJettonMinter: SandboxContract<ZkJettonMinter>,
    zkJettonWallet: SandboxContract<ZkJettonWallet>,
) {
    let { proof, publicSignals } = await createMintProof(keys);

    const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

    const verifyResult = await zkJettonMinter.send(
        owner.getSender(),
        {
            value: toNano('0.3'),
        },
        {
            $$type: 'Mint',
            receiver: user.address,
            mintMessage: {
                $$type: 'ZkJettonTransferInternal',
                amount: pubInputs[0],
                amountRevert: pubInputs[0],
                sender: zkJettonMinter.address,
            },
            piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
            piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
            piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
            pubInputs: dictFromInputList(pubInputs),
        },
    );

    expect(
        await zkJettonMinter.getVerifyMint(
            beginCell().storeBuffer(pi_a).endCell().asSlice(),
            beginCell().storeBuffer(pi_b).endCell().asSlice(),
            beginCell().storeBuffer(pi_c).endCell().asSlice(),
            dictFromInputList(pubInputs),
        ),
    ).toBeTruthy();

    expect(verifyResult.transactions).toHaveTransaction({
        from: owner.address,
        to: zkJettonMinter.address,
        success: true,
    });

    const encryptedBalance = (await zkJettonWallet.getWalletData()).balance;
    const balance = keys.privateKey.decrypt(encryptedBalance);
    expect(balance).toBe(mintValue);
}

export function getMintData(keys: paillierBigint.KeyPair) {
    const value = mintValue;
    const rand_r = getRandomBigInt(keys.publicKey.n);
    const encryptedValue = keys.publicKey.encrypt(value, rand_r);
    const receiverPubKey = [keys.publicKey.g, rand_r, keys.publicKey.n];

    return { encryptedValue, value, receiverPubKey };
}

export async function createMintProof(keys: paillierBigint.KeyPair) {
    return await snarkjs.groth16.fullProve(getMintData(keys), wasmPath, zkeyPath);
}
