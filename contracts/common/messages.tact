//  SPDX-License-Identifier: MIT
//  Copyright © 2025 TON Studio

struct ZkJettonData {
    mintable: Bool;
    owner: Address;
    content: Cell;
    jettonWalletCode: Cell;
}
struct ZkJettonWalletData {
    balance: Int;
    owner: Address;
    minter: Address;
    code: Cell;
    key: Key;
}
struct MaybeAddress {
    address: Address?;
}
message(4) JettonUpdateContent {
    queryId: Int as uint64;
    content: Cell;
}
message(0x7362d09c) JettonNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    forwardPayload: Slice as remaining;
}
message(0xd53276db) JettonExcesses {
    queryId: Int as uint64;
}
message(0x2c76b973) ProvideWalletAddress {
    queryId: Int as uint64;
    ownerAddress: Address;
    includeAddress: Bool;
}
message(0xd1735400) TakeWalletAddress {
    queryId: Int as uint64;
    walletAddress: Address;
    ownerAddress: Cell?; //It is Maybe ^Address, just encoded it like this
}
// provide_wallet_balance#7ac8d559 receiver:MsgAddress include_verify_info:Bool = InternalMsgBody
message(0x7ac8d559) ProvideWalletBalance {
    receiver: Address;
    includeVerifyInfo: Bool;
}
struct VerifyInfo {
    owner: Address;
    minter: Address;
    code: Cell;
}
// verify_info$_ owner:MsgAddress minter:MsgAddress code:^Cell = VerifyInfo
// take_wallet_balance#ca77fdc2 balance:Coins verify_info:(Maybe VerifyInfo) = InternalMsgBody
message(0xca77fdc2) TakeWalletBalance {
    balance: Int as coins;
    verifyInfo: VerifyInfo?;
}
// claim_ton#0393b1ce receiver:MsgAddress = InternalMsgBody
message(0x0393b1ce) ClaimTON {
    receiver: Address;
}
// zkJetton
struct Key {
    g: Int as uint224;
    n: Int as uint224;
    powN2: Int as uint224;
}
message Registration {
    piA: Slice;
    piB: Slice;
    piC: Slice;
    pubInputs: map<Int as uint32, Int as uint224>;
}
message JettonTransfer {
    amount: Int as uint224;
    queryId: Int as uint64;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}
message JettonTransferInternal {
    amount: Int as uint224;
    queryId: Int as uint64;
    sender: Address;
    responseDestination: Address?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}
message Mint {
    receiver: Address;
    mintMessage: JettonTransferInternal;
    piA: Slice;
    piB: Slice;
    piC: Slice;
    pubInputs: map<Int as uint32, Int as uint224>;
}