import "@stdlib/ownable";

import "./zk-jetton-wallet";
import "./common/messages";

import "./verifiers_traits/verifier_mint";

contract ZkJettonMinter  with MintVerifier, Ownable {
    owner: Address;
    jettonContent: Cell;
    mintable: Bool;
    jettonWalletCode: Cell;
    nonce: Int as uint64;

    init(
        owner: Address,
        jettonContent: Cell,
        mintable: Bool
    ) {
        self.owner = owner;
        self.jettonContent = jettonContent;
        self.mintable = mintable;
        self.jettonWalletCode = codeOf ZkJettonWallet;
        self.nonce = 0;
    }

    receive(msg: Mint) {
        let ctx = context();
        require(ctx.value >= ton("0.1"), "Insufficient fee for ZK verification");
        require(self.mintable, "Mint is closed");
        require(self.owner == ctx.sender, "Receiver must be sender");
        require(msg.nonce == self.nonce, "Invalid nonce");
        require(self.groth16Verify_mint(msg.piA, msg.piB, msg.piC, msg.pubInputs), "Invalid ZK proof");

        let proofNonce = msg.pubInputs.get(4)!!;
        require(proofNonce == self.nonce, "Invalid proof nonce");

        let proofReceiverHash = msg.pubInputs.get(3)!!;
        require(proofReceiverHash == sha256(msg.receiver.toString()), "Invalid proof nonce");

        self.nonce += 1;

        message(MessageParameters {
            to: getZkJettonWalletByOwner(msg.receiver),
            value: ton("0.05"),
            mode: 0,
            bounce: false,
            body: msg.mintMessage.toCell(),
        });
    }

    receive(msg: ZkJettonUpdateContent) {
        self.requireOwner();
        self.jettonContent = msg.content;
        emit("ZkJettonMinter:ZkJettonUpdateContent".asComment())
    }

    receive(msg: UpdateMintable) {
        self.requireOwner();
        self.mintable = msg.newMintable;
        emit("ZkJettonMinter:UpdateMintable".asComment())
    }

    get fun jetton_data(): ZkJettonMinterState {
        return ZkJettonMinterState {
            mintable: self.mintable,
            ownerAddress: self.owner,
            jettonContent: self.jettonContent,
            jettonWalletCode: codeOf ZkJettonWallet,
            nonce: self.nonce,
        };
    }

    get fun wallet_address(ownerAddress: Address): Address {
        return getZkJettonWalletByOwner(ownerAddress);
    }

    get fun nonce(): Int {
        return self.nonce;
    }
}

inline fun getZkJettonWalletInit(address: Address): StateInit {
    return initOf ZkJettonWallet(address, myAddress(), 0);
}

inline fun getZkJettonWalletByOwner(jettonWalletOwner: Address): Address {
    return contractAddress(getZkJettonWalletInit(jettonWalletOwner));
}
