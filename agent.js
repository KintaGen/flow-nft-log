// agent.js

require("dotenv").config();
const fcl = require("@onflow/fcl");
const fs = require("fs");
const path = require("path");
const { ec: EllipticCurve } = require("elliptic");
const { SHA3 } = require("sha3");

// --- Configuration ---
const TESTNET_ADDRESS = process.env.TESTNET_ADDRESS;
const TESTNET_PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY;
console.log("--- Agent Configuration ---");
if (!TESTNET_ADDRESS || !TESTNET_PRIVATE_KEY) {
  console.error("🔴 FATAL ERROR: Missing .env variables.");
  process.exit(1);
}
console.log(`✅ Loaded Address: ${TESTNET_ADDRESS}`);
console.log(`✅ Loaded Private Key: ${TESTNET_PRIVATE_KEY.substring(0, 4)}...`);
console.log("---------------------------\n");

// --- Hardcoded Addresses ---
const KINTAGEN_NFT_ADDRESS = TESTNET_ADDRESS;
const NON_FUNGIBLE_TOKEN_ADDRESS = "0x631e88ae7f1d7c20";
const METADATA_VIEWS_ADDRESS = "0x631e88ae7f1d7c20";

// --- FCL Config ---
fcl.config({ "accessNode.api": "https://rest-testnet.onflow.org" });

// --- Authorization ---
const ec = new EllipticCurve("p256");
const keyId = 0;
const sign = (message) => {
  const key = ec.keyFromPrivate(Buffer.from(TESTNET_PRIVATE_KEY, "hex"));
  const sig = key.sign(hash(message));
  const n = 32;
  const r = sig.r.toArrayLike(Buffer, "be", n);
  const s = sig.s.toArrayLike(Buffer, "be", n);
  return Buffer.concat([r, s]).toString("hex");
};
const hash = (message) => {
  const sha = new SHA3(256);
  sha.update(Buffer.from(message, "hex"));
  return sha.digest();
};
const authorizationFunction = async (account) => {
  return {
    ...account, tempId: `${TESTNET_ADDRESS}-${keyId}`,
    addr: fcl.sansPrefix(TESTNET_ADDRESS), keyId: Number(keyId),
    signingFunction: async (signable) => ({
      addr: fcl.withPrefix(TESTNET_ADDRESS),
      keyId: Number(keyId),
      signature: sign(signable.message),
    }),
  };
};

// --- Main Action ---
const mintNft = async () => {
    console.log("🤖 Agent starting work...");
    const agentName = "Node.js Agent (Template Method)";

    // 1. Read the Cadence template from the file system.
    const cadenceTemplate = fs.readFileSync(path.join(__dirname, "./cadence/transactions/agent_mint_template.cdc"), "utf8");
    
    // 2. Replace all placeholders with our hardcoded addresses.
    const cadence = cadenceTemplate
        .replace("0xNON_FUNGIBLE_TOKEN_ADDRESS", NON_FUNGIBLE_TOKEN_ADDRESS)
        .replace("0xMETADATA_VIEWS_ADDRESS", METADATA_VIEWS_ADDRESS)
        .replace("0xKINTAGEN_NFT_ADDRESS", KINTAGEN_NFT_ADDRESS);
    
    console.log("Submitting transaction to Testnet...");

    try {
        const transactionId = await fcl.mutate({
            cadence,
            args: (arg, t) => [
                arg(TESTNET_ADDRESS, t.Address), arg(agentName, t.String),
                arg("bafkreia-sdk-mint-final", t.String), arg("sdk-run-hash-final", t.String),
            ],
            proposer: authorizationFunction, payer: authorizationFunction,
            authorizations: [authorizationFunction], limit: 999
        });
        console.log(`✅ Mint transaction submitted! TX ID: ${transactionId}`);
        console.log(`🔗 View on Flowdiver: https://testnet.flowdiver.io/tx/${transactionId}`);
        const result = await fcl.tx(transactionId).onceSealed();
        
        if (result.status === 4) {
            const mintedEvent = result.events.find(e => e.type.includes('.KintaGenNFT.Minted'));
            if (mintedEvent) {
                console.log(`🎉 Success! New KintaGenNFT minted with ID: ${mintedEvent.data.id}`);
            } else {
                console.error("🔴 Minted event not found in transaction result.", result);
            }
        } else {
            console.error(`🔴 Transaction failed with status: ${result.status}. Error: ${result.errorMessage}`);
        }
    } catch (error) {
        console.error("🔴 Error during minting transaction:", error);
    }
};

const main = async () => {
    await mintNft();
    console.log("\n✨ Agent simulation complete.");
}

main();