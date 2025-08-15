import { toNano } from '@ton/core';
import { ZkJetton } from '../build/ZkJetton/ZkJetton_ZkJetton';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const zkJetton = provider.open(await ZkJetton.fromInit());

    await zkJetton.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        null,
    );

    await provider.waitForDeploy(zkJetton.address);

    // run methods on `zkJetton`
}
