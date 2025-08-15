//  SPDX-License-Identifier: MIT
//  Copyright © 2025 TON Studio

import "./common/messages";
import "./common/constants";
import "./common/utils";

import "./verifiers traints/verifier_registration";

contract ZkJettonWallet with RegistrationVerifier {
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

    receive(msg: JettonTransfer) {
        forceBasechain(msg.destination);
        require(sender() == self.owner, "Incorrect sender");

        self.balance -= msg.amount;
        require(self.balance >= 0, "Incorrect balance after send");
        checkEitherForwardPayload(msg.forwardPayload);

        let ctx = context();
        let fwdCount = 1 + sign(msg.forwardTonAmount); // msg.forwardTonAmount is coins, so it's positive
        require(
            ctx.value >
            msg.forwardTonAmount +
            fwdCount * ctx.readForwardFee() +
            getForwardFee(walletStateInitCells, walletStateInitBits, false) +
            (2 * getComputeFee(gasForTransfer, false) + minTonsForStorage),
            "Insufficient amount of TON attached",
        );

        deploy(DeployParameters {
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: JettonTransferInternal {
                queryId: msg.queryId,
                amount: msg.amount,
                sender: self.owner,
                responseDestination: msg.responseDestination,
                forwardTonAmount: msg.forwardTonAmount,
                forwardPayload: msg.forwardPayload,
            }.toCell(),
            init: initOf ZkJettonWallet(msg.destination, self.minter, 0),
        });
    }

    receive(msg: JettonTransferInternal) {
        self.balance += msg.amount;

        self.balance = (self.balance * msg.amount) % self.key.powN2;

        // This message should come only from master, or from other JettonWallet
        let wallet: StateInit = initOf ZkJettonWallet(msg.sender, self.minter, 0);
        if (!wallet.hasSameBasechainAddress(sender())) {
            require(self.minter == sender(), "Incorrect sender");
        }

        let ctx: Context = context();
        let msgValue: Int = ctx.value;
        let tonBalanceBeforeMsg = myBalance() - msgValue;

        if (msg.forwardTonAmount > 0) {
            let fwdFee: Int = ctx.readForwardFee();
            msgValue -= msg.forwardTonAmount + fwdFee;
            message(MessageParameters {
                to: self.owner,
                value: msg.forwardTonAmount,
                mode: SendPayGasSeparately,
                bounce: false,
                body: JettonNotification { // 0x7362d09c -- Remind the new Owner
                    queryId: msg.queryId,
                    amount: msg.amount,
                    sender: msg.sender,
                    forwardPayload: msg.forwardPayload,
                }.toCell(),
            });
        }
        nativeReserve(max(tonBalanceBeforeMsg, minTonsForStorage), ReserveAtMost);
        // 0xd53276db -- Cashback to the original Sender
        if (msg.responseDestination != null && msgValue > 0) {
            message(MessageParameters {
                to: msg.responseDestination!!,
                value: msgValue,
                mode: SendRemainingBalance + SendIgnoreErrors,
                bounce: false,
                body: JettonExcesses { queryId: msg.queryId }.toCell(),
            });
        }
    }

    receive(msg: ProvideWalletBalance) {
        let info: VerifyInfo? = null;
        if (msg.includeVerifyInfo) {
            info = VerifyInfo {
                minter: self.minter,
                owner: self.owner,
                code: myCode(),
            };
        }

        message(MessageParameters {
            body: TakeWalletBalance {
                balance: self.balance,
                verifyInfo: info,
            }.toCell(),
            to: msg.receiver,
            value: 0,
            mode: SendRemainingValue,
        });
    }

    bounced(msg: bounced<JettonTransferInternal>) {
        // TODO: handle bounced transfer
        self.balance += msg.amount;
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