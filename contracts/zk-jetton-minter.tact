import "./zk-jetton-wallet";
import "./common/messages";
import "./common/constants";

import "./verifiers traints/verifier_mint";

struct ZkJettonMinterState {
    mintable: Bool;
    adminAddress: Address;
    jettonContent: Cell;
    jettonWalletCode: Cell;
}

contract ZkJettonMinter(
    owner: Address,
    jettonContent: Cell,
    mintable: Bool,
) with MintVerifier {
    receive(msg: Mint) {
        require(sender() == self.owner, "Incorrect sender");
        require(self.mintable, "Mint is closed");
        require(self.groth16Verify_mint(
            msg.piA, msg.piB, msg.piC, msg.pubInputs
        ), "Invalid proof");

        message(MessageParameters {
            to: getZkJettonWalletByOwner(msg.receiver),
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: msg.mintMessage.toCell(),
        });
    }

    receive(msg: ZkJettonUpdateContent) {
        require(sender() == self.owner, "Incorrect sender");
        self.jettonContent = msg.content;
    }

    get fun get_jetton_data(): ZkJettonMinterState {
        return ZkJettonMinterState {
            mintable: self.mintable,
            adminAddress: self.owner,
            jettonContent: self.jettonContent,
            jettonWalletCode: codeOf ZkJettonWallet,
        };
    }

    get fun get_wallet_address(ownerAddress: Address): Address {
        return getZkJettonWalletByOwner(ownerAddress);
    }
}

inline fun getZkJettonWalletInit(address: Address): StateInit {
    return initOf ZkJettonWallet(address, myAddress(), 0);
}

inline fun getZkJettonWalletByOwner(jettonWalletOwner: Address): Address {
    return contractAddress(getZkJettonWalletInit(jettonWalletOwner));
}
