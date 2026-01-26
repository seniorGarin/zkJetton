import "@stdlib/ownable";
import "./common/messages";
import "./common/utils";

import "./verifiers_traits/verifier_registration";
import "./verifiers_traits/verifier_transfer";
import "./zk-jetton-wallet";

contract ZkJettonWallet with RegistrationVerifier, VerifierTransfer, Ownable {
    owner: Address;
    minter: Address;
    balance: Int as uint224;
    nonce: Int as uint64;
    key: Key; // { g: Int, n: Int, powN2: Int }

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
        require(self.balance == 0, "ALREADY_REGISTERED");

        if (!self.groth16Verify_registration(msg.piA, msg.piB, msg.piC, msg.pubInputs)) {
            throw(300); // Invalid zk-proof
        }

        let claimedBalance = msg.pubInputs.get(0)!!;
        let claimedG = msg.pubInputs.get(1)!!;
        let claimedN = msg.pubInputs.get(3)!!;

        require(claimedBalance >= 0 && claimedBalance <= MAX_UINT224, "INVALID_BALANCE");
        require(claimedG > 1 && claimedG <= MAX_UINT64, "INVALID_G");
        require(claimedN > 1 && claimedN <= MAX_UINT64, "INVALID_N");

        self.balance = claimedBalance;
        self.key = Key{
            g: claimedG,
            n: claimedN,
            powN2: pow(claimedN, 2)
        };
    }

    receive(msg: ZkJettonTransfer) {
        forceBasechain(msg.receiver);
        require(sender() == self.owner, "NOT_OWNER");
        require(self.groth16Verify_transfer(msg.piA, msg.piB, msg.piC, msg.pubInputs), "Invalid ZK proof");

        let proofNonce = msg.pubInputs.get(3)!!;
        require(proofNonce == self.nonce, "INVALID_NONCE");

        let multiplier = msg.pubInputs.get(1)!!;
        require(multiplier > 1, "INVALID_MULTIPLIER");
        require(multiplier < self.key.powN2, "MULTIPLIER_OVERFLOW");
        require(isCoprimeWithNSquared(multiplier, self.key.n), "MULTIPLIER_NOT_INVERTIBLE");

        let amount = msg.pubInputs.get(2)!!;
        require(amount > 0, "ZERO_AMOUNT");
        require(amount < self.key.powN2, "AMOUNT_TOO_LARGE");

        let amountRevert = modInverse(multiplier, self.key.powN2);
        require(amountRevert != 0, "NO_MODULAR_INVERSE");

        self.balance = (self.balance * multiplier) % self.key.powN2;
        self.nonce += 1;

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
    }

    receive(msg: ZkJettonTransferInternal) {
        let expectedSenderAddr: StateInit = initOf ZkJettonWallet(msg.sender, self.minter, 0);
        if (!expectedSenderAddr.hasSameBasechainAddress(sender())) {
            require(sender() == self.minter, "UNAUTHORIZED_SENDER");
        }

        require(msg.amount > 0, "INVALID_AMOUNT_INTERNAL");
        if (self.balance != 0) {
            self.balance = (self.balance * msg.amount) % self.key.powN2;
        } else {
            require(sender() == self.minter, "Only minter can initialize balance");
            self.balance = msg.amount;
        }
    }

    bounced(msg: bounced<ZkJettonTransferInternal>) {
        let amountRevert = msg.amountRevert;
        require(amountRevert > 0, "INVALID_REVERT_VALUE");
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