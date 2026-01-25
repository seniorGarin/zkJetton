import "@stdlib/ownable";

import "./common/messages";
import "./common/utils";

import "./verifiers_traits/verifier_registration";
import "./verifiers_traits/verifier_transfer";

contract ZkJettonWallet with RegistrationVerifier, VerifierTransfer, Ownable {
    owner: Address;
    minter: Address;
    balance: Int as uint224;
    nonce: Int as uint64;
    key: Key;

    init(
        owner: Address,
        minter: Address,
        balance: Int as uint224
    )  {
        self.owner = owner;
        self.minter = minter;
        self.balance = balance;
        self.nonce = 0;
        self.key = Key{g: 0, n: 0, powN2: 0};
    }

    receive(msg: Registration) {
        self.requireOwner();
        require(self.balance == 0, "you are registered");
        if(self.groth16Verify_registration(msg.piA, msg.piB, msg.piC, msg.pubInputs)) {
            self.balance = msg.pubInputs.get(0)!!;
            self.key.g = msg.pubInputs.get(1)!!;
            self.key.n = msg.pubInputs.get(3)!!;
            self.key.powN2 = pow(msg.pubInputs.get(3)!!, 2);
        } else {
            nativeThrow(300); // wrong proof
        }
    }

    receive(msg: ZkJettonTransfer) {
        forceBasechain(msg.receiver);
        require(sender() == self.owner, "Incorrect sender");

        msg.pubInputs.set(3, self.nonce);

        if (self.groth16Verify_transfer(msg.piA, msg.piB, msg.piC, msg.pubInputs)) {
            let multiplier: Int = msg.pubInputs.get(1)!!;
            self.balance = (self.balance * multiplier) % self.key.powN2;
            self.nonce += 1;

            let amount: Int = msg.pubInputs.get(2)!!;
            let amountRevert: Int = modInverse(multiplier, self.key.powN2);

            message(MessageParameters {
                to: contractAddress(initOf ZkJettonWallet(msg.receiver, self.minter, 0)),
                value: 0,
                mode: SendRemainingValue,
                bounce: true,
                body: ZkJettonTransferInternal {
                    amount,
                    amountRevert,
                    sender: self.owner,
                }.toCell(),
            });
        } else {
            nativeThrow(300); // wrong proof
        }
    }

    receive(msg: ZkJettonTransferInternal) {
        let wallet: StateInit = initOf ZkJettonWallet(msg.sender, self.minter, 0);
        if (!wallet.hasSameBasechainAddress(sender())) {
            require(self.minter == sender(), "Incorrect sender");
        }

        self.balance = (self.balance * msg.amount) % self.key.powN2;
    }

    bounced(msg: bounced<ZkJettonTransferInternal>) {
        let amountRevert = msg.amountRevert;
        self.balance = (self.balance * amountRevert) % self.key.powN2;
    }

    get fun wallet_data(): ZkJettonWalletData {
        return ZkJettonWalletData {
            balance: self.balance,
            owner: self.owner,
            minter: self.minter,
            nonce: self.nonce,
            key: self.key,
            code: myCode(),
        };
    }
}