/* get-story.mjs — Node ≥ 20, Flow Testnet */

import * as fcl from "@onflow/fcl";

/* 1️⃣  FCL CONFIG - THE FIX IS HERE */
const KINTAGEN_NFT_ADDRESS = "0x4971e1983b20b758";
const METADATA_VIEWS_ADDRESS = "0x631e88ae7f1d7c20"; // This is the address for ViewResolver

fcl.config()
  .put("accessNode.api", "https://rest-testnet.onflow.org")
  .put("0xKintaGenNFT", KINTAGEN_NFT_ADDRESS)
  // ViewResolver is part of the MetadataViews contract, so we point to its address
  .put("0xViewResolver", METADATA_VIEWS_ADDRESS); 


/* 2️⃣  CADENCE SCRIPT */
const cadence = `
  import ViewResolver from 0xViewResolver
  import KintaGenNFT from 0xKintaGenNFT

  access(all) fun main(ownerAddress: Address, nftID: UInt64): [KintaGenNFT.WorkflowStepView]? {
      let owner = getAccount(ownerAddress)
      
      let collectionCap = owner.capabilities
          .get<&{ViewResolver.ResolverCollection}>(KintaGenNFT.CollectionPublicPath)
      
      if collectionCap.borrow() == nil {
        panic("Could not borrow a reference to the collection capability.")
      }

      let resolver = collectionCap.borrow()!.borrowViewResolver(id: nftID)
          ?? panic("Could not borrow view resolver for KintaGenNFT.")
          
      let storyView = resolver.resolveView(Type<KintaGenNFT.WorkflowStepView>())
      
      return storyView as? [KintaGenNFT.WorkflowStepView]
  }
`;

/* 3️⃣  JS WRAPPER */
export async function getWorkflowStory(ownerAddress, nftId) {
  if (!nftId) {
    console.error("🔴 Please provide an NFT ID to fetch.");
    return;
  }

  try {
    const story = await fcl.query({
      cadence,
      args: (arg, t) => [
        arg(ownerAddress, t.Address),
        arg(nftId, t.UInt64),
      ],
    });

    console.log(`\n--- Workflow Story for NFT #${nftId} ---`);
    if (story && story.length > 0) {
      story.forEach(step => {
        console.log(`
  Step:      ${step.stepNumber}
  Agent:     ${step.agent}
  Action:    ${step.action}
  ResultCID: ${step.resultCID}
  Timestamp: ${new Date(parseFloat(step.timestamp) * 1000).toUTCString()}
        `);
      });
    } else {
      console.log("No story found or the log is empty.");
    }
    console.log("--------------------------------------");

    return story;
  } catch (error) {
    console.error(`🔴 Error fetching story for NFT #${nftId}:`, error);
  }
}


/* 4️⃣  QUICK TEST */
(async () => {
  const nftIdToFetch = process.argv[2]; 
  if (!nftIdToFetch) {
    console.log("Usage: node get-story.mjs <NFT_ID>");
    return;
  }
  console.log(`🔍 Fetching workflow story for NFT #${nftIdToFetch}...`);
  await getWorkflowStory(KINTAGEN_NFT_ADDRESS, nftIdToFetch);
})();