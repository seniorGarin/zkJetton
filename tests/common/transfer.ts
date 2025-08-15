import paillierBigint from 'paillier-bigint';
import * as snarkjs from 'snarkjs';
import path from 'path';

import { SandboxContract, TreasuryContract } from '@ton/sandbox';

import { getRandomBigInt, transferValue } from './common';
import { ZkJettonWallet } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';

const wasmPath = path.join(__dirname, '../../circuits/transfer/transfer_js', 'transfer.wasm');
const zkeyPath = path.join(__dirname, '../../circuits/transfer', 'transfer_final.zkey');
const verificationKey = require('../../circuits/transfer/verification_key.json');

export async function transfer(
    keysA: paillierBigint.KeyPair,
    keysB: paillierBigint.KeyPair,
    zkJettonWallet: ZkJettonWallet,
    user1: SandboxContract<TreasuryContract>,
    user2: SandboxContract<TreasuryContract>,
) {
    // const encryptedBalanceABefor = await zkToken.balanceOf(userA.address);
    // const balanceABefore = keysA.privateKey.decrypt(encryptedBalanceABefor);
    // const encryptedBalanceBBefor = await zkToken.balanceOf(userB.address);
    // const balanceBBefore = keysB.privateKey.decrypt(encryptedBalanceBBefor);
    // const { proof, publicSignals } = await createTransferProof(keysA, keysB, encryptedBalanceABefor);
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
