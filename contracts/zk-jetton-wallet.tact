import "./common/messages";

import "./verifiers_traits/verifier_registration";
import "./verifiers_traits/verifier_transfer";

contract ZkJettonWallet with RegistrationVerifier, VerifierTransfer {
    owner: Address;
    minter: Address;
    balance: Int as uint224;
    key: Key;

    init(
        owner: Address,
        minter: Address,
        balance: Int as uint224
    )  {
        self.owner = owner;
        self.minter = minter;
        self.balance = balance;
        self.key = Key{g: 0, n: 0, powN2: 0};
    }

    receive(msg: Registration) {
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

        msg.pubInputs.set(0, self.balance);

        if(self.groth16Verify_transfer(msg.piA, msg.piB, msg.piC, msg.pubInputs)) {
            self.balance = (self.balance * msg.pubInputs.get(1)!!) % self.key.powN2;

            message(MessageParameters {
                to: contractAddress(initOf ZkJettonWallet(msg.receiver, self.minter, 0)),
                value: 0,
                mode: SendRemainingValue,
                bounce: true,
                body: ZkJettonTransferInternal {
                    amount: msg.pubInputs.get(2)!!,
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
        // TODO: Design and implement a mechanism for returning the balance.
    }

    get fun get_wallet_data(): ZkJettonWalletData {
        return ZkJettonWalletData {
            balance: self.balance,
            owner: self.owner,
            minter: self.minter,
            key: self.key,
            code: myCode(),
        };
    }
}