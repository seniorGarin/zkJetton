//  SPDX-License-Identifier: MIT
//  Copyright © 2025 TON Studio

import "./zk-jetton-wallet";
import "./common/messages";
import "./common/constants";

import "./verifiers traints/verifier_mint";

struct JettonMinterState {
    mintable: Bool;
    adminAddress: Address;
    jettonContent: Cell;
    jettonWalletCode: Cell;
}

contract ZkJettonMinter(
    owner: Address,
    jettonContent: Cell,
    mintable: Bool, // Should be deployed with this flag set to true
) with MintVerifier {
    receive(msg: ProvideWalletAddress) {
        let ownerWorkchain: Int = parseStdAddress(msg.ownerAddress.asSlice()).workchain;

        // If owner is basechain address, we can calculate jettonWallet
        let targetJettonWallet: BasechainAddress = (ownerWorkchain == Basechain)
            ? contractBasechainAddress(getJettonWalletInit(msg.ownerAddress))
            : emptyBasechainAddress();

        message(MessageParameters {
            body: makeTakeWalletAddressMsg(targetJettonWallet, msg),
            to: sender(),
            value: 0,
            mode: SendRemainingValue,
        });
    }

    // Owner of this contract may be masterchain address,
    // however minting is possible only to basechain addresses
    // it is asserted inside the deploy function
    receive(msg: Mint) {
        require(sender() == self.owner, "Incorrect sender");
        require(self.mintable, "Mint is closed");
        require(self.groth16Verify_mint(
            msg.piA, msg.piB, msg.piC, msg.pubInputs
        ), "Invalid proof");

        checkEitherForwardPayload(msg.mintMessage.forwardPayload);

        let ctx = context();
        // we don't add compute fees for mint itself and reserve here
        // it's okay since it’s sent only by the admin and excesses will return back
        require(
            ctx.value >
            minTonsForStorage +
            msg.mintMessage.forwardTonAmount +
            ctx.readForwardFee() +
            getForwardFee(walletStateInitCells, walletStateInitBits, false) +
            2 * getComputeFee(gasForTransfer, false),
            "Insufficient gas for mint",
        );


        // basechain destination is calculated inside deploy function
        deploy(DeployParameters {
            value: 0, // ignore msg.tonAmount and use SendMode 64 instead
            bounce: true,
            mode: SendRemainingValue | SendBounceIfActionFail,
            body: msg.mintMessage.toCell(),
            init: getJettonWalletInit(msg.receiver),
        });
    }

    receive(msg: JettonUpdateContent) {
        require(sender() == self.owner, "Incorrect sender");
        self.jettonContent = msg.content;
    }

    get fun get_jetton_data(): JettonMinterState {
        return JettonMinterState {
            mintable: self.mintable,
            adminAddress: self.owner,
            jettonContent: self.jettonContent,
            jettonWalletCode: codeOf ZkJettonWallet,
        };
    }

    get fun get_wallet_address(ownerAddress: Address): Address {
        return getJettonWalletByOwner(ownerAddress);
    }
}

inline fun getJettonWalletInit(address: Address): StateInit {
    return initOf ZkJettonWallet(address, myAddress(), 0);
}

inline fun getJettonWalletByOwner(jettonWalletOwner: Address): Address {
    return contractAddress(getJettonWalletInit(jettonWalletOwner));
}

inline fun makeTakeWalletAddressMsg(targetJettonWallet: BasechainAddress, msg: ProvideWalletAddress): Cell {
    return beginCell()
        .storeUint(TakeWalletAddress.opcode(), 32)
        .storeUint(msg.queryId, 64)
        .storeBasechainAddress(targetJettonWallet)
        .storeMaybeRef(msg.includeAddress ? beginCell().storeAddress(msg.ownerAddress).endCell() : null)
        .endCell();
}
