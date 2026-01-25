import paillierBigint from 'paillier-bigint';
import { SandboxContract, TreasuryContract, Blockchain } from '@ton/sandbox';
import { ZkJettonWallet } from '../../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';
import { dictFromInputList, groth16CompressProof } from 'export-ton-verifier';
import { beginCell, toNano } from '@ton/core';

import { createTransferProof } from './transfer'; // можно вынести в общий файл, чтобы не дублировать

export async function transferWithBounce(
    keys1: paillierBigint.KeyPair,
    keys2: paillierBigint.KeyPair,
    zkJettonWallet1: SandboxContract<ZkJettonWallet>,
    user1: SandboxContract<TreasuryContract>,
    blockchain: Blockchain,
) {
    const wallet1DataBefore = await zkJettonWallet1.getWalletData();
    const encryptedBalance1Before = wallet1DataBefore.balance;
    const balance1Before = keys1.privateKey.decrypt(encryptedBalance1Before);
    const nonceBefore = wallet1DataBefore.nonce;

    const { proof, publicSignals } = await createTransferProof(keys1, keys2, encryptedBalance1Before, nonceBefore);
    const { pi_a, pi_b, pi_c, pubInputs } = await groth16CompressProof(proof, publicSignals);

    const bogus = await blockchain.treasury('bogus_receiver');

    expect(
        await zkJettonWallet1.getVerifyTransfer(
            beginCell().storeBuffer(pi_a).endCell().asSlice(),
            beginCell().storeBuffer(pi_b).endCell().asSlice(),
            beginCell().storeBuffer(pi_c).endCell().asSlice(),
            dictFromInputList(pubInputs),
        ),
    ).toBeTruthy();

    const res = await zkJettonWallet1.send(
        user1.getSender(),
        { value: toNano('1') },
        {
            $$type: 'ZkJettonTransfer',
            receiver: bogus.address, // <- специально НЕ zkJettonWallet2.address
            piA: beginCell().storeBuffer(pi_a).endCell().asSlice(),
            piB: beginCell().storeBuffer(pi_b).endCell().asSlice(),
            piC: beginCell().storeBuffer(pi_c).endCell().asSlice(),
            pubInputs: dictFromInputList(pubInputs),
        },
    );

    expect(res.transactions).toHaveTransaction({
        from: user1.address,
        to: zkJettonWallet1.address,
        success: true,
    });

    expect(res.transactions).toHaveTransaction({
        to: zkJettonWallet1.address,
        inMessageBounced: true,
    });

    const wallet1DataAfter = await zkJettonWallet1.getWalletData();
    const encryptedBalance1After = wallet1DataAfter.balance;
    const balance1After = keys1.privateKey.decrypt(encryptedBalance1After);

    expect(balance1After).toBe(balance1Before);
}
