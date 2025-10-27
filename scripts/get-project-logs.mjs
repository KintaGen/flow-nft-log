/* scripts/get-project-logs.mjs — retrieve workflow story for PublicKintaGenNFTv2 NFTs */

import * as fcl from "@onflow/fcl";
import "dotenv/config";

const prefer = (...values) => values.find(v => v !== undefined && v !== "") ?? null;
const strip0x = addr => (addr ?? "").replace(/^0x/, "");

const NETWORK = (process.env.FLOW_NETWORK ?? process.env.NETWORK ?? "testnet").toLowerCase();
const SERVICE_ADDRESS_CORE = strip0x(
  prefer(
    process.env.FLOW_ADDRESS,
    process.env.TESTNET_ADDRESS,
    process.env.EMULATOR_ADDRESS,
    "f8d6e0586b0a20c7"
  )
);
const SERVICE_ADDRESS = `0x${SERVICE_ADDRESS_CORE}`;

const NETWORK_CONFIG = {
  emulator: {
    accessNode: "http://127.0.0.1:8889",
    PublicKintaGen: "0xf8d6e0586b0a20c7",
  },
  testnet: {
    accessNode: "https://rest-testnet.onflow.org",
    PublicKintaGen: SERVICE_ADDRESS,
  },
};

const NET = NETWORK_CONFIG[NETWORK];
if (!NET) {
  console.error(`🔴 Unsupported FLOW_NETWORK "${NETWORK}". Use "emulator" or "testnet".`);
  process.exit(1);
}

fcl.config()
  .put("accessNode.api", NET.accessNode)
  .put("0xPublicKintaGenNFTv2", NET.PublicKintaGen)
  .put("flow.network", NETWORK);

const cadence = `
import PublicKintaGenNFTv2 from 0xPublicKintaGenNFTv2

access(all) fun main(owner: Address, id: UInt64): [{String: AnyStruct}] {
    let collection = getAccount(owner)
        .capabilities
        .borrow<&PublicKintaGenNFTv2.Collection>(PublicKintaGenNFTv2.CollectionPublicPath)
        ?? panic("Owner does not expose a PublicKintaGenNFTv2 collection capability")

    let resolver = collection.borrowViewResolver(id: id)
        ?? panic("NFT not found in collection")

    let steps = resolver
        .resolveView(Type<[PublicKintaGenNFTv2.WorkflowStepView]>())!
        as! [PublicKintaGenNFTv2.WorkflowStepView]

    var result: [{String: AnyStruct}] = []
    var i = 0
    while i < steps.length {
        let step = steps[i]
        result.append({
            "step": step.stepNumber,
            "agent": step.agent,
            "title": step.title,
            "description": step.description,
            "cid": step.ipfsHash,
            "timestamp": step.timestamp
        })
        i = i + 1
    }
    return result
}
`;

export async function getProjectLogs({ owner, nftId }) {
  const response = await fcl.query({
    cadence,
    args: (arg, t) => [
      arg(owner, t.Address),
      arg(String(nftId), t.UInt64),
    ],
  });

  return response;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [owner, nftId] = process.argv.slice(2);

  if (!owner || nftId === undefined) {
    console.log(`
Usage:
  node scripts/get-project-logs.mjs <owner-address> <nftId>

Example:
  node scripts/get-project-logs.mjs 0xf8d6e0586b0a20c7 0
    `);
    process.exit(0);
  }

  getProjectLogs({ owner, nftId })
    .then(logs => {
      console.dir(logs, { depth: null, colors: true });
    })
    .catch(err => {
      console.error("🔴 Failed to fetch logs:", err);
      process.exit(1);
    });
}
