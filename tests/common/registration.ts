import paillierBigint from 'paillier-bigint';
import * as snarkjs from 'snarkjs';
import path from 'path';

import { SandboxContract, TreasuryContract } from '@ton/sandbox';

import { dictFromInputList, groth16CompressProof } from 'export-ton-verifier';

import { getRandomBigInt, initBalance } from './common';
import { ZkJettonWallet } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';
import { beginCell, toNano } from '@ton/core';

const wasmPath = path.join(__dirname, '../../circuits/registration/registration_js', 'registration.wasm');
const zkeyPath = path.join(__dirname, '../../circuits/registration', 'registration_final.zkey');

export async function registration(
    keys: paillierBigint.KeyPair,
    zkJettonWallet: SandboxContract<ZkJettonWallet>,
    user: SandboxContract<TreasuryContract>,
) {
    const { proof, publicSignals } = await createRegistrationProof(keys);
    const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

    const verifyResult = await zkJettonWallet.send(
        user.getSender(),
        {
            value: toNano('0.3'),
        },
        {
            $$type: 'Registration',
            piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
            piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
            piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
            pubInputs: dictFromInputList(pubInputs),
        },
    );

    expect(
        await zkJettonWallet.getVerifyRegistration(
            beginCell().storeBuffer(pi_a).endCell().asSlice(),
            beginCell().storeBuffer(pi_b).endCell().asSlice(),
            beginCell().storeBuffer(pi_c).endCell().asSlice(),
            dictFromInputList(pubInputs),
        ),
    ).toBeTruthy();

    expect(verifyResult.transactions).toHaveTransaction({
        from: user.address,
        to: zkJettonWallet.address,
        success: true,
    });

    const encryptedBalance = (await zkJettonWallet.getWalletData()).balance;
    const balance = keys.privateKey.decrypt(encryptedBalance);
    expect(balance).toBe(initBalance);

    const pubKey = (await zkJettonWallet.getWalletData()).key;

    expect(pubKey.g).toBe(keys.publicKey.g);
    expect(pubKey.n).toBe(keys.publicKey.n);
    expect(pubKey.powN2).toBe(keys.publicKey._n2);
}

export function getRegistrationData(keys: paillierBigint.KeyPair) {
    const balance = initBalance;
    const rand_r = getRandomBigInt(keys.publicKey.n);
    const encryptedBalance = keys.publicKey.encrypt(balance, rand_r);
    const pubKey = [keys.publicKey.g, rand_r, keys.publicKey.n];

    return { encryptedBalance, balance, pubKey };
}

export function getRegistrationDataFromPub(pub: paillierBigint.PublicKey) {
    const balance = initBalance;
    const rand_r = getRandomBigInt(pub.n);
    const encryptedBalance = pub.encrypt(balance, rand_r);
    const pubKey = [pub.g, rand_r, pub.n];

    return { encryptedBalance, balance, pubKey };
}

export async function createRegistrationProof(keys: paillierBigint.KeyPair) {
    return await snarkjs.groth16.fullProve(getRegistrationData(keys), wasmPath, zkeyPath);
}
