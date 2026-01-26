pragma circom 2.2.1;

include "binpower.circom";
include "../node_modules/circomlib/circuits/comparators.circom"; // GreaterThan и LessThan

template Main() {
    signal input encryptedValue;
    signal input receiverG;
    signal input receiverN;
    signal input receiverHash;

    signal input nonce;
    signal input amount;
    signal input r;
    signal input q; // witness

    // amount > 0
    component gtZero = GreaterThan(128);
    gtZero.in[0] <== amount;
    gtZero.in[1] <== 0;
    gtZero.out === 1;

    signal n2;
    n2 <== receiverN * receiverN;

    component powG = Binpower();
    powG.b <== receiverG;
    powG.e <== amount;
    powG.modulo <== n2;

    component powR = Binpower();
    powR.b <== r;
    powR.e <== receiverN;
    powR.modulo <== n2;

    signal product;
    product <== powG.out * powR.out;

    signal rhs;
    product === q * n2 + encryptedValue;

    component lt = LessThan(252);
    lt.in[0] <== encryptedValue;
    lt.in[1] <== n2;
    lt.out === 1;
}

component main {
    public [
        nonce,
        encryptedValue,
        receiverG,
        receiverN,
        receiverHash
    ]
} = Main();