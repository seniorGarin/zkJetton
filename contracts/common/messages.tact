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
    nonce: Int;
    key: Key;
}
message(4) ZkJettonUpdateContent {
    queryId: Int as uint64;
    content: Cell;
}
message(0x2c76b973) ProvideWalletAddress {
    queryId: Int as uint64;
    ownerAddress: Address;
    includeAddress: Bool;
}
struct VerifyInfo {
    owner: Address;
    minter: Address;
    code: Cell;
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
message ZkJettonTransferInternal {
    amount: Int as uint224;
    sender: Address
}
message Mint {
    receiver: Address;
    mintMessage: ZkJettonTransferInternal;
    piA: Slice;
    piB: Slice;
    piC: Slice;
    pubInputs: map<Int as uint32, Int as uint224>;
}
message ZkJettonTransfer {
    receiver: Address;
    piA: Slice;
    piB: Slice;
    piC: Slice;
    pubInputs: map<Int as uint32, Int as uint224>;
}