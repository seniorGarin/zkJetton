import paillierBigint from 'paillier-bigint';
import * as snarkjs from 'snarkjs';
import path from 'path';

import { SandboxContract, TreasuryContract } from '@ton/sandbox';

import { getRandomBigInt, transferValue } from './common';
import { ZkJettonWallet } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';
import { dictFromInputList, groth16CompressProof } from 'export-ton-verifier';
import { beginCell, toNano } from '@ton/core';

const wasmPath = path.join(__dirname, '../../circuits/transfer/transfer_js', 'transfer.wasm');
const zkeyPath = path.join(__dirname, '../../circuits/transfer', 'transfer_final.zkey');

export async function transfer(
    keys1: paillierBigint.KeyPair,
    keys2: paillierBigint.KeyPair,
    zkJettonWallet1: SandboxContract<ZkJettonWallet>,
    zkJettonWallet2: SandboxContract<ZkJettonWallet>,
    user1: SandboxContract<TreasuryContract>,
    user2: SandboxContract<TreasuryContract>,
) {
    const encryptedBalance1Befor = (await zkJettonWallet1.getGetWalletData()).balance;
    const balance1Before = keys1.privateKey.decrypt(encryptedBalance1Befor);

    const encryptedBalance2Befor = (await zkJettonWallet2.getGetWalletData()).balance;
    const balance2Before = keys2.privateKey.decrypt(encryptedBalance2Befor);

    const { proof, publicSignals } = await createTransferProof(keys1, keys2, encryptedBalance1Befor);
    const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

    const verifyResult = await zkJettonWallet1.send(
        user1.getSender(),
        {
            value: toNano('1'),
        },
        {
            $$type: 'ZkJettonTransfer',
            receiver: user2.address,
            piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
            piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
            piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
            pubInputs: dictFromInputList(pubInputs),
        },
    );

    expect(
        await zkJettonWallet1.getVerifyTransfer(
            beginCell().storeBuffer(pi_a).endCell().asSlice(),
            beginCell().storeBuffer(pi_b).endCell().asSlice(),
            beginCell().storeBuffer(pi_c).endCell().asSlice(),
            dictFromInputList(pubInputs),
        ),
    ).toBe(true);

    expect(verifyResult.transactions).toHaveTransaction({
        from: user1.address,
        to: zkJettonWallet1.address,
        success: true,
    });

    expect(verifyResult.transactions).toHaveTransaction({
        from: zkJettonWallet1.address,
        to: zkJettonWallet2.address,
        success: true,
    });

    const encryptedBalance1After = (await zkJettonWallet1.getGetWalletData()).balance;
    const balance1 = keys1.privateKey.decrypt(encryptedBalance1After);
    expect(balance1Before - transferValue).toBe(balance1);

    const encryptedBalance2After = (await zkJettonWallet2.getGetWalletData()).balance;
    const balance2 = keys2.privateKey.decrypt(encryptedBalance2After);
    expect(balance2Before + transferValue).toBe(balance2);
}

export async function createTransferProof(
    senderKeys: paillierBigint.KeyPair,
    receiverKeys: paillierBigint.KeyPair,
    encryptedSenderBalance: bigint,
) {
    return await snarkjs.groth16.fullProve(
        getTransferData(senderKeys, receiverKeys, encryptedSenderBalance),
        wasmPath,
        zkeyPath,
    );
}

export function getTransferData(
    senderKeys: paillierBigint.KeyPair,
    receiverKeys: paillierBigint.KeyPair,
    encryptedSenderBalance: bigint,
) {
    const value = transferValue;
    const sender_rand_r = getRandomBigInt(senderKeys.publicKey.n);
    const receiver_rand_r = getRandomBigInt(receiverKeys.publicKey.n);
    const encryptedSenderValue = senderKeys.publicKey.encrypt(senderKeys.publicKey.n - value, sender_rand_r);
    const encryptedReceiverValue = receiverKeys.publicKey.encrypt(value, receiver_rand_r);
    const senderPubKey = [senderKeys.publicKey.g, sender_rand_r, senderKeys.publicKey.n];
    const receiverPubKey = [receiverKeys.publicKey.g, receiver_rand_r, receiverKeys.publicKey.n];
    const senderPrivKey = [senderKeys.privateKey.lambda, senderKeys.privateKey.mu, senderKeys.privateKey.n];

    return {
        encryptedSenderBalance,
        encryptedSenderValue,
        encryptedReceiverValue,
        value,
        senderPubKey,
        receiverPubKey,
        senderPrivKey,
    };
}
