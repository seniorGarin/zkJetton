export const initBalance = 0n;

export const mintValue = 1000n;

export const transferValue = 500n;

export function getRandomBigInt(max: bigint) {
    return BigInt(Math.floor(Math.random() * Number(max.toString())));
}
