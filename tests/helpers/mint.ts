import paillierBigint from 'paillier-bigint';
import { modPow } from 'bigint-mod-arith';
import * as snarkjs from 'snarkjs';
import path from 'path';

import { SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, toNano, Address } from '@ton/core';
import { dictFromInputList, groth16CompressProof } from 'export-ton-verifier';

import { getRandomBigInt, mintValue } from './index';
import { ZkJettonMinter } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonMinter';
import { ZkJettonWallet } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';
import { sha256 } from '@ton/crypto';

const wasmPath = path.join(__dirname, '../../circuits/mint/mint_js', 'mint.wasm');
const zkeyPath = path.join(__dirname, '../../circuits/mint', 'mint_final.zkey');

export async function mint(
    keys: paillierBigint.KeyPair,
    owner: SandboxContract<TreasuryContract>,
    user: SandboxContract<TreasuryContract>,
    zkJettonMinter: SandboxContract<ZkJettonMinter>,
    zkJettonWallet: SandboxContract<ZkJettonWallet>,
) {

    const minterNonce = await zkJettonMinter.getNonce();
    let { proof, publicSignals } = await createMintProof(keys, minterNonce, user.address);
    const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

    const verifyResult = await zkJettonMinter.send(
        owner.getSender(),
        {
            value: toNano('0.3'),
        },
        {
            $$type: 'Mint',
            receiver: user.address,
            nonce: minterNonce,
            mintMessage: {
                $$type: 'ZkJettonTransferInternal',
                amount: pubInputs[0],
                amountRevert: 0n, // not used
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

export async function createMintProof(keys: paillierBigint.KeyPair, minterNonce: bigint, receiverAddress: Address) {
    return await snarkjs.groth16.fullProve(await getMintData(keys, minterNonce, receiverAddress), wasmPath, zkeyPath);
}

export async function getMintData(keys: paillierBigint.KeyPair, minterNonce: bigint, receiverAddress: Address) {
    const amount = mintValue;
    const r = getRandomBigInt(keys.publicKey.n);
    const n2 = keys.publicKey.n * keys.publicKey.n;
    const g_pow = keys.publicKey.g;

    const g_to_amount = modPow(g_pow, amount, n2); // g^amount mod n²
    const r_to_n = modPow(r, keys.publicKey.n, n2); // r^n mod n²
    const encryptedValue = (g_to_amount * r_to_n) % n2;
    const fullProduct = g_to_amount * r_to_n;
    const q = fullProduct / n2;

    const receiverHash = BigInt(`0x${(await sha256(Buffer.from(receiverAddress.toString()))).toString('hex')}`);

    return {
        nonce: minterNonce,
        encryptedValue: encryptedValue.toString(),
        receiverG: g_pow.toString(),
        receiverN: keys.publicKey.n.toString(),
        receiverHash,
        amount: amount.toString(),
        r: r.toString(),
        q: q.toString(),
    };
}
