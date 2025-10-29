# zkJetton

zkJetton is a minimal version of a jetton contract for the TON blockchain that uses zk-SNARKs in **Tact** to provide hidden balances and private transfer amounts.

For more details, see the [Tact documentation on zk-proofs](https://docs.tact-lang.org/cookbook/zk-proofs/).


# How it works

* Balances are encrypted using a **homomorphic cryptosystem (Paillier)**.
* The sender computes the transfer amount locally and generates a proof of correct computation.
* The smart contract updates balances homomorphically (adding to the recipient, subtracting from the sender).
* The proof is verified inside the contract before applying the state change.

# Technology stack

- Tact
- Circom (groth16, bls12-381)
- SnarkJS
- paillier-bigint
- export-ton-verifier

## Circom

### Registration

```sh
circom registration.circom --r1cs --wasm --sym --prime bls12381

snarkjs powersoftau new bls12-381 10 pot10_0000.ptau -v
snarkjs powersoftau contribute pot10_0000.ptau pot10_0001.ptau --name="First contribution" -v -e="some random text"
snarkjs powersoftau prepare phase2 pot10_0001.ptau pot10_final.ptau -v
snarkjs groth16 setup registration.r1cs pot10_final.ptau registration_0000.zkey
snarkjs zkey contribute registration_0000.zkey registration_final.zkey --name="1st Contributor Name" -v -e="some random text"
snarkjs zkey export verificationkey registration_final.zkey verification_key.json

cd ../..

npx export-ton-verifier ./circuits/registration/registration_final.zkey ./contracts/verifiers/verifier_registration.tact --tact
```

### Mint

```sh
circom mint.circom --r1cs --wasm --sym --prime bls12381

snarkjs powersoftau new bls12-381 10 pot10_0000.ptau -v
snarkjs powersoftau contribute pot10_0000.ptau pot10_0001.ptau --name="First contribution" -v -e="some random text"
snarkjs powersoftau prepare phase2 pot10_0001.ptau pot10_final.ptau -v
snarkjs groth16 setup mint.r1cs pot10_final.ptau mint_0000.zkey
snarkjs zkey contribute mint_0000.zkey mint_final.zkey --name="1st Contributor Name" -v -e="some random text"
snarkjs zkey export verificationkey mint_final.zkey verification_key.json

cd ../..

npx export-ton-verifier ./circuits/mint/mint_final.zkey ./contracts/verifiers/verifier_mint.tact --tact
```

### Transfer

```sh
circom transfer.circom --r1cs --wasm --sym --prime bls12381

snarkjs powersoftau new bls12-381 10 pot10_0000.ptau -v
snarkjs powersoftau contribute pot10_0000.ptau pot10_0001.ptau --name="First contribution" -v -e="some random text"
snarkjs powersoftau prepare phase2 pot10_0001.ptau pot10_final.ptau -v
snarkjs groth16 setup transfer.r1cs pot10_final.ptau transfer_0000.zkey
snarkjs zkey contribute transfer_0000.zkey transfer_final.zkey --name="1st Contributor Name" -v -e="some random text"
snarkjs zkey export verificationkey transfer_final.zkey verification_key.json

cd ../..

npx export-ton-verifier ./circuits/Transfer/transfer_final.zkey ./contracts/verifiers/verifier_transfer.tact --tact
```

# Disclaimer

All Tact and Circom code, practices and patterns in this repository are for educational purposes only.

DO NOT USE IN PRODUCTION.
