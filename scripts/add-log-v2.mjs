/* scripts/add-log-v2.mjs — append workflow steps to PublicKintaGenNFTv2 NFTs */

import * as fcl from "@onflow/fcl";
import ellipticPkg from "elliptic";
import sha3Pkg from "js-sha3";
import "dotenv/config";

const { ec: EC } = ellipticPkg;
const { sha3_256 } = sha3Pkg;
const ec = new EC("p256");

// ---------- Environment helpers ----------
const prefer = (...values) => values.find(v => v !== undefined && v !== "") ?? null;
const strip0x = addr => (addr ?? "").replace(/^0x/, "");

const NETWORK = (process.env.FLOW_NETWORK ?? process.env.NETWORK ?? "testnet").toLowerCase();
const SERVICE_ADDRESS_CORE = strip0x(
  prefer(
    process.env.FLOW_ADDRESS,
    process.env.TESTNET_ADDRESS,
    process.env.EMULATOR_ADDRESS,
    "f8d6e0586b0a20c7" // emulator default
  )
);

const PRIVATE_KEY = prefer(
  process.env.FLOW_PRIVATE_KEY,
  process.env.TESTNET_PRIVATE_KEY,
  process.env.EMULATOR_PRIVATE_KEY,
  NETWORK === "emulator" ? "b62fe8ce66aa2a8d77e2ee701e136d781aa88d036c0b6775c6d3ec3266706056" : null
);

const KEY_INDEX = Number(process.env.FLOW_KEY_INDEX ?? 0);

if (!SERVICE_ADDRESS_CORE) {
  console.error("🔴 Missing account address. Set FLOW_ADDRESS or TESTNET_ADDRESS in .env");
  process.exit(1);
}

if (!PRIVATE_KEY) {
  console.error("🔴 Missing private key. Set FLOW_PRIVATE_KEY or TESTNET_PRIVATE_KEY in .env");
  process.exit(1);
}

const SERVICE_ADDRESS = `0x${SERVICE_ADDRESS_CORE}`;

const NETWORK_CONFIG = {
  emulator: {
    accessNode: "http://127.0.0.1:8889",
    NonFungibleToken: "0xf8d6e0586b0a20c7",
    PublicKintaGen: "0xf8d6e0586b0a20c7",
  },
  testnet: {
    accessNode: "https://rest-testnet.onflow.org",
    NonFungibleToken: "0x631e88ae7f1d7c20",
    PublicKintaGen: SERVICE_ADDRESS,
  },
};

const NET = NETWORK_CONFIG[NETWORK];
if (!NET) {
  console.error(`🔴 Unsupported FLOW_NETWORK "${NETWORK}". Use "emulator" or "testnet".`);
  process.exit(1);
}

// ---------- FCL configuration ----------
fcl.config()
  .put("accessNode.api", NET.accessNode)
  .put("0xNonFungibleToken", NET.NonFungibleToken)
  .put("0xPublicKintaGenNFTv2", NET.PublicKintaGen)
  .put("flow.network", NETWORK);

// ---------- Signer configuration ----------
function signWithP256SHA3(messageHex) {
  const key = ec.keyFromPrivate(Buffer.from(PRIVATE_KEY, "hex"));
  const digest = Buffer.from(sha3_256.arrayBuffer(Buffer.from(messageHex, "hex")));
  const signature = key.sign(digest, { canonical: true });

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
    signature: signWithP256SHA3(signable.message),
  }),
});

// ---------- Cadence transaction ----------
const cadence = `
import PublicKintaGenNFTv2 from 0xPublicKintaGenNFTv2

transaction(nftID: UInt64, agent: String, title: String, details: String, cid: String) {

    prepare(signer: auth(BorrowValue) &Account) {
        let collection = signer.storage.borrow<&PublicKintaGenNFTv2.Collection>(
            from: PublicKintaGenNFTv2.CollectionStoragePath
        ) ?? panic("PublicKintaGenNFTv2 collection not found in signer storage")

        let nft = collection.borrowNFT(nftID)! as! &PublicKintaGenNFTv2.NFT
        nft.addLogEntry(agent: agent, title: title, description: details, ipfsHash: cid)
    }
}
`;

export async function addLogEntry({ nftId, agent, title, details, cid }) {
  const txId = await fcl.mutate({
    cadence,
    args: (arg, t) => [
      arg(String(nftId), t.UInt64),
      arg(agent, t.String),
      arg(title, t.String),
      arg(details, t.String),
      arg(cid, t.String),
    ],
    proposer: authorization,
    payer: authorization,
    authorizations: [authorization],
    limit: 200,
  });

  console.log("📮 Submitted transaction:", txId);
  const sealed = await fcl.tx(txId).onceSealed();
  console.log("✅ Transaction sealed:", sealed.statusString);
  return sealed;
}

// ---------- CLI runner ----------
if (import.meta.url === `file://${process.argv[1]}`) {
  const [nftId, agent, title, details, cid] = process.argv.slice(2);

  if (!nftId || !agent || !title || !details || !cid) {
    console.log(`
Usage:
  node scripts/add-log-v2.mjs <nftId> "<agent>" "<title>" "<details>" "<ipfsCid>"

Example:
  node scripts/add-log-v2.mjs 0 "Dr. Ada" "Sequencing Run" "Sequenced batch" "bafy..."
    `);
    process.exit(0);
  }

  addLogEntry({ nftId, agent, title, details, cid }).catch(err => {
    console.error("🔴 Failed to add log entry:", err);
    process.exit(1);
  });
}
