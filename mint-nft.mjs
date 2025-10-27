import * as fcl from "@onflow/fcl";
import ellipticPkg from "elliptic";
import sha3Pkg from "js-sha3";

const { ec: EC } = ellipticPkg;
const { sha3_256 } = sha3Pkg;
const ec = new EC("p256");

/* 1️⃣  EMULATOR-ACCOUNT CREDS and CONFIG */
const EMULATOR_ADDRESS = "0xf8d6e0586b0a20c7";
const EMULATOR_PRIVATE_KEY = "99d8f5af01d30c5abe73fac78fea17b72f7c2b902693c8bb9f9e889b24693aa4"; 
const KEY_INDEX = 0;

if (!EMULATOR_PRIVATE_KEY) {
  console.error("🔴 FATAL ERROR: Please paste your private key from flow.json into this script.");
  process.exit(1);
}

/* 2️⃣  FCL CONFIG FOR EMULATOR (Corrected to match flow.json deployment) */
fcl.config()
  .put("accessNode.api", "http://127.0.0.1:8888") // Your REST API port
  .put("0xKintaGenNFT", EMULATOR_ADDRESS)
  .put("0xNonFungibleToken", EMULATOR_ADDRESS)
  .put("0xMetadataViews", EMULATOR_ADDRESS)
  .put("0xViewResolver", EMULATOR_ADDRESS)
  .put("0xFlowToken", "0x0ae53cb6e3f42a79")
  .put("0xFungibleToken", "0xee82856bf20e2aa6");

/* 3️⃣  SERVER-SIDE SIGNING LOGIC (Unchanged) */
function signWithP256Sha3(messageHex) {
  const key = ec.keyFromPrivate(Buffer.from(EMULATOR_PRIVATE_KEY, "hex"));
  const msgHash = Buffer.from(sha3_256.arrayBuffer(Buffer.from(messageHex, "hex")));
  const signature = key.sign(msgHash, { canonical: true });
  return Buffer.concat([
    signature.r.toArrayLike(Buffer, "be", 32),
    signature.s.toArrayLike(Buffer, "be", 32),
  ]).toString("hex");
}
const authorization = (acct = {}) => ({
  ...acct,
  tempId: `${EMULATOR_ADDRESS}-${KEY_INDEX}`,
  addr: fcl.withPrefix(EMULATOR_ADDRESS),
  keyId: KEY_INDEX,
  signingFunction: async signable => ({
    addr: fcl.withPrefix(EMULATOR_ADDRESS),
    keyId: KEY_INDEX,
    signature: signWithP256Sha3(signable.message),
  }),
});

const cadence = `
  import FungibleToken from 0xFungibleToken
  import FlowToken from 0xFlowToken
  import NonFungibleToken from 0xNonFungibleToken
  import KintaGenNFT from 0xKintaGenNFT
  import ViewResolver from 0xViewResolver

  transaction(agent: String, outputCID: String, runHash: String) {
      
      let collectionRef: &{NonFungibleToken.Receiver}
      let feePaymentVault: @FlowToken.Vault
      let minterRef: &KintaGenNFT.Minter
      let signerAddress: Address

      prepare(signer: auth(Storage, Capabilities) &Account) {
          self.signerAddress = signer.address

          if signer.storage.borrow<&KintaGenNFT.Collection>(from: KintaGenNFT.CollectionStoragePath) == nil {
              signer.storage.save(<-KintaGenNFT.createEmptyCollection(nftType: Type<@KintaGenNFT.NFT>()), to: KintaGenNFT.CollectionStoragePath)
              
              signer.capabilities.publish(
                  signer.capabilities.storage.issue<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, ViewResolver.ResolverCollection}>(KintaGenNFT.CollectionStoragePath),
                  at: KintaGenNFT.CollectionPublicPath
              )
          }

          self.collectionRef = signer.capabilities.borrow<&{NonFungibleToken.Receiver}>(KintaGenNFT.CollectionPublicPath)!
          
          self.minterRef = getAccount(0xKintaGenNFT).capabilities.borrow<&KintaGenNFT.Minter>(KintaGenNFT.MinterPublicPath)!
          
          let mainVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)!
          self.feePaymentVault <- mainVault.withdraw(amount: KintaGenNFT.mintingFee) as! @FlowToken.Vault
      }

      execute {
          let feeReceiver = getAccount(0xKintaGenNFT).capabilities.borrow<&{FungibleToken.Receiver}>(KintaGenNFT.FeeReceiverPublicPath)!
          feeReceiver.deposit(from: <-self.feePaymentVault)

          let nft <- self.minterRef.mint(
              agent: agent,
              outputCID: outputCID,
              runHash: runHash,
              owner: self.signerAddress 
          )
          
          self.collectionRef.deposit(token: <-nft)
          log("✅ Fee paid and NFT Minted")
      }
  }
`;

/* 5️⃣  JS WRAPPER (Unchanged) */
export async function mintNFT({ agent, outputCID, runHash }) {
  console.log(`Minting NFT for agent "${agent}"...`);
  try {
    const txId = await fcl.mutate({
      cadence,
      args: (arg, t) => [
        arg(agent, t.String),
        arg(outputCID, t.String),
        arg(runHash, t.String),
      ],
      proposer: authorization,
      payer: authorization,
      authorizations: [authorization],
      limit: 999,
    });

    console.log("✅ Transaction submitted! TX ID:", txId);
    const sealed = await fcl.tx(txId).onceSealed();
    console.log(`🎉 Transaction sealed → ${sealed.statusString}`);
    
    const mintEvent = sealed.events.find(e => e.type.includes('KintaGenNFT.Minted'));
    if (mintEvent) {
      console.log(`✨ Successfully minted NFT with ID: ${mintEvent.data.id}`);
      return mintEvent.data.id;
    }
    return null;
  } catch (error) {
    console.error("🔴 Error minting NFT:", error);
  }
}

/* 6️⃣  QUICK TEST RUNNER (Unchanged) */
(async () => {
  await mintNFT({
    agent: "Emulator Test Project",
    outputCID: "bafy...initialCID",
    runHash: "run-12345"
  });
})();