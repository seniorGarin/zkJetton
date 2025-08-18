import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, toNano } from '@ton/core';
import '@ton/test-utils';

import paillierBigint from 'paillier-bigint';

import { ZkJettonMinter } from '../build/zkJettonMinter/zkJettonMinter_ZkJettonMinter';
import { ZkJettonWallet } from '../build/zkJettonMinter/zkJettonMinter_ZkJettonWallet';
import { registration } from './common/registration';
import { mint } from './common/mint';
import { transfer } from './common/transfer';

// npx blueprint test zkJetton.spec.ts
describe('zkJetton', () => {
    let blockchain: Blockchain;
    let owner: SandboxContract<TreasuryContract>;
    let user1: SandboxContract<TreasuryContract>;
    let user2: SandboxContract<TreasuryContract>;

    let zkJettonMinter: SandboxContract<ZkJettonMinter>;
    let zkJettonWalletUser1: SandboxContract<ZkJettonWallet>;
    let zkJettonWalletUser2: SandboxContract<ZkJettonWallet>;

    let keys1: paillierBigint.KeyPair;
    let keys2: paillierBigint.KeyPair;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        owner = await blockchain.treasury('owner');
        user1 = await blockchain.treasury('user1');
        user2 = await blockchain.treasury('user2');

        keys1 = await paillierBigint.generateRandomKeys(32);
        keys2 = await paillierBigint.generateRandomKeys(32);

        zkJettonMinter = blockchain.openContract(
            await ZkJettonMinter.fromInit(owner.address, beginCell().endCell(), true),
        );
        zkJettonWalletUser1 = blockchain.openContract(
            await ZkJettonWallet.fromInit(user1.address, zkJettonMinter.address, 0n),
        );
        zkJettonWalletUser2 = blockchain.openContract(
            await ZkJettonWallet.fromInit(user2.address, zkJettonMinter.address, 0n),
        );

        const deployResult = await zkJettonMinter.send(
            owner.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'ZkJettonUpdateContent',
                queryId: 0n,
                content: beginCell().endCell(),
            },
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: owner.address,
            to: zkJettonMinter.address,
            deploy: true,
            success: true,
        });
    });

    it('zkJettonMinter deploy', async () => {
        expect((await zkJettonMinter.getGetJettonData()).adminAddress.equals(owner.address)).toBe(true);
        expect((await zkJettonMinter.getGetJettonData()).mintable).toBe(true);
    });

    it('Registration', async () => {
        await registrationPhase();
    });

    it('Mint', async () => {
        await registrationPhase();
        await mintPhase();
    });

    it('Transfer', async () => {
        await registrationPhase();
        await mintPhase();
        await transferPhase();
    });

    async function registrationPhase() {
        await registration(keys1, zkJettonWalletUser1, user1);
        await registration(keys2, zkJettonWalletUser2, user2);
    }

    async function mintPhase() {
        await mint(keys1, owner, user1, zkJettonMinter, zkJettonWalletUser1);
    }

    async function transferPhase() {
        await transfer(keys1, keys2, zkJettonWalletUser1, zkJettonWalletUser2, user1, user2);
    }
});
