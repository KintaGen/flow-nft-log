/* add-log-entry.mjs — Node ≥ 20, Flow Testnet */

import * as fcl from "@onflow/fcl";
import ellipticPkg from "elliptic";
import sha3Pkg from "js-sha3";
import 'dotenv/config'; // To automatically load .env file

const { ec: EC } = ellipticPkg;
const { sha3_256 } = sha3Pkg;
const ec = new EC("p256");

/* 1️⃣  SERVICE-ACCOUNT CREDS and CONFIG */
const SERVICE_ADDRESS = process.env.TESTNET_ADDRESS;
const PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY;
const KEY_INDEX = 0;

if (!SERVICE_ADDRESS || !PRIVATE_KEY) {
  console.error("🔴 FATAL ERROR: Missing TESTNET_ADDRESS or TESTNET_PRIVATE_KEY in your .env file.");
  process.exit(1);
}

const KINTAGEN_NFT_ADDRESS = SERVICE_ADDRESS;

/* 2️⃣  FCL CONFIG */
fcl.config()
  .put("accessNode.api", "https://rest-testnet.onflow.org")
  .put("0xKintaGenNFT", KINTAGEN_NFT_ADDRESS)
  .put("0xNonFungibleToken", "0x631e88ae7f1d7c20");

/* 3️⃣  SERVER-SIDE SIGNING LOGIC */
function signWithP256Sha3(messageHex) {
  const key = ec.keyFromPrivate(Buffer.from(PRIVATE_KEY, "hex"));
  const msgHash = Buffer.from(sha3_256.arrayBuffer(Buffer.from(messageHex, "hex")));
  const signature = key.sign(msgHash, { canonical: true });
  return Buffer.concat([
    signature.r.toArrayLike(Buffer, "be", 32),
    signature.s.toArrayLike(Buffer, "be", 32),
  ]).toString("hex");
}

const authorization = (acct = {}) => ({
  ...acct,
  tempId: `${SERVICE_ADDRESS}-${KEY_INDEX}`,
  addr: fcl.withPrefix(SERVICE_ADDRESS),
  keyId: KEY_INDEX,
  signingFunction: async signable => ({
    addr: fcl.withPrefix(SERVICE_ADDRESS),
    keyId: KEY_INDEX,
    signature: signWithP256Sha3(signable.message),
  }),
});

/* 4️⃣  CADENCE TRANSACTION - THE FIX IS HERE */
// This transaction now correctly calls `addLogEntry` with only the three
// arguments that your deployed contract expects.
const cadence = `
  import NonFungibleToken from 0xNonFungibleToken
  import KintaGenNFT from 0xKintaGenNFT

  transaction(nftID: UInt64, agent: String, actionDescription: String, outputCID: String) {
      
      let nftRef: &KintaGenNFT.NFT

      prepare(signer: auth(BorrowValue) &Account) {
          let collection = signer.storage.borrow<&KintaGenNFT.Collection>(from: KintaGenNFT.CollectionStoragePath)
              ?? panic("Could not borrow a reference to the owner's Collection")

          self.nftRef = collection.borrowNFT(nftID)! as! &KintaGenNFT.NFT
      }

      execute {
          // CORRECTED: Call with only three arguments
          self.nftRef.addLogEntry(
              agent: agent,
              actionDescription: actionDescription,
              outputCID: outputCID
          )
          log("✅ Successfully added new log entry to NFT")
      }
  }
`;

/* 5️⃣  JS WRAPPER */
export async function addLogEntry({ nftId, agent, action, outputCID }) {
  console.log(`Submitting log entry for NFT #${nftId}...`);
  try {
    const txId = await fcl.mutate({
      cadence,
      args: (arg, t) => [
        arg(nftId, t.UInt64),
        arg(agent, t.String),
        arg(action, t.String),
        arg(outputCID, t.String),
      ],
      proposer: authorization,
      payer: authorization,
      authorizations: [authorization],
      limit: 999,
    });

    console.log("✅ Transaction submitted! TX ID:", txId);
    console.log(`🔗 View on Flowdiver: https://testnet.flowdiver.io/tx/${txId}`);

    const sealed = await fcl.tx(txId).onceSealed();
    console.log(`🎉 Transaction sealed → ${sealed.statusString}`);
    return sealed;
  } catch (error) {
    console.error("🔴 Error adding log entry:", error);
  }
}

/* 6️⃣  QUICK TEST (Command-Line Runner) */
(async () => {
  const [nftId, agent, action, outputCID] = process.argv.slice(2);

  if (!nftId || !agent || !action || !outputCID) {
    console.log(`
  Usage: 
    node add-log-entry.mjs <nftId> "<agent>" "<action>" "<outputCID>"

  Example:
    node add-log-entry.mjs 171523814068370 "agent-beta" "Validated results" "bafy...CID"
    `);
    return;
  }

  await addLogEntry({ nftId, agent, action, outputCID });
})();