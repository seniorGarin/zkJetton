import paillierBigint from 'paillier-bigint';
import * as snarkjs from 'snarkjs';
import path from 'path';

import { SandboxContract, TreasuryContract } from '@ton/sandbox';

import { getRandomBigInt, mintValue } from './common';
import { ZkJettonMinter } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonMinter';

const wasmPath = path.join(__dirname, '../../circuits/mint/mint_js', 'mint.wasm');
const zkeyPath = path.join(__dirname, '../../circuits/mint', 'mint_final.zkey');
const verificationKey = require('../../circuits/mint/verification_key.json');

export async function mint(
    keys: paillierBigint.KeyPair,
    zkJettonWallet: ZkJettonMinter,
    user: SandboxContract<TreasuryContract>,
) {
    let { proof, publicSignals } = await createMintProof(keys);
}

export function getMintData(keys: paillierBigint.KeyPair) {
    const value = mintValue;
    const rand_r = getRandomBigInt(keys.publicKey.n);
    const encryptedValue = keys.publicKey.encrypt(value, rand_r);
    const receiverPubKey = [keys.publicKey.g, rand_r, keys.publicKey.n];

    console.log('Minting value:', encryptedValue);

    return { encryptedValue, value, receiverPubKey };
}

export async function createMintProof(keys: paillierBigint.KeyPair) {
    return await snarkjs.groth16.fullProve(getMintData(keys), wasmPath, zkeyPath);
}
