/* get-all-ids.mjs — Node ≥ 20, Flow Testnet */

import * as fcl from "@onflow/fcl";

/* 1️⃣  FCL CONFIG */
const KINTAGEN_NFT_ADDRESS = "0x4971e1983b20b758"; // The address where your contract is deployed
fcl.config()
  .put("accessNode.api", "https://rest-testnet.onflow.org")
  .put("0xKintaGenNFT", KINTAGEN_NFT_ADDRESS);


/* 2️⃣  CADENCE SCRIPT */
const cadence = `
  import KintaGenNFT from 0xKintaGenNFT

  // This script reads all the NFT IDs from the main KintaGenNFT collection
  // owned by the contract deployer account.
  access(all) fun main(ownerAddress: Address): [UInt64] {
      
      let owner = getAccount(ownerAddress)

      let collectionRef = owner.capabilities
          .get<&KintaGenNFT.Collection>(KintaGenNFT.CollectionPublicPath)
          .borrow()
          ?? panic("Could not borrow a reference to the KintaGenNFT Collection.")

      // Call the getIDs() function on the collection
      return collectionRef.getIDs()
  }
`;

/* 3️⃣  JS WRAPPER */
export async function getAllNftIds(ownerAddress) {
  try {
    const ids = await fcl.query({
      cadence,
      args: (arg, t) => [arg(ownerAddress, t.Address)],
    });

    console.log("✅ Successfully fetched NFT IDs:", ids);
    return ids;
  } catch (error) {
    console.error("🔴 Error fetching NFT IDs:", error);
    return [];
  }
}


/* 4️⃣  QUICK TEST */
(async () => {
  console.log("🔍 Fetching all NFT IDs from account:", KINTAGEN_NFT_ADDRESS);
  await getAllNftIds(KINTAGEN_NFT_ADDRESS);
})();