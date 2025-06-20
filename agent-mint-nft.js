/* agent.mjs — Node ≥ 20, Flow Testnet */

import ellipticPkg from "elliptic";
import sha3Pkg     from "js-sha3";
import * as fcl    from "@onflow/fcl";

const { ec: EC }   = ellipticPkg;
const { sha3_256 } = sha3Pkg;
const ec           = new EC("p256");

/* 1️⃣  SERVICE-ACCOUNT CREDS */
const SERVICE_ADDRESS = "4971e1983b20b758";   // no 0x
const PRIVATE_KEY     = "9d6d47f1025d49a8e7e8e8dab66cf949a6d11aa39f3a41e141ee23d97903afdd";
const KEY_INDEX       = 0;

/* 2️⃣  FCL CONFIG */
fcl.config()
  .put("accessNode.api",      "https://rest-testnet.onflow.org")
  .put("0xNonFungibleToken",  "0x631e88ae7f1d7c20")
  .put("0xKintaGenNFT",       "0x4971e1983b20b758")
  .put("0xMetadataViews",     "0x631e88ae7f1d7c20");

/* 3️⃣  P-256 + SHA3-256 SIGNER */
function signWithP256Sha3(messageHex) {
  const key       = ec.keyFromPrivate(Buffer.from(PRIVATE_KEY, "hex"));
  const msgHash   = Buffer.from(sha3_256.arrayBuffer(Buffer.from(messageHex, "hex")));
  const signature = key.sign(msgHash, { canonical: true });

  return Buffer.concat([
    signature.r.toArrayLike(Buffer, "be", 32),
    signature.s.toArrayLike(Buffer, "be", 32),
  ]).toString("hex");
}

/* 4️⃣  TWO-PHASE AUTHORIZER REQUIRED BY FCL v2 */
const authorization = (acct = {}) => ({
  ...acct,
  tempId: `${SERVICE_ADDRESS}-${KEY_INDEX}`,
  addr:   fcl.withPrefix(SERVICE_ADDRESS),
  keyId:  KEY_INDEX,
  signingFunction: async signable => ({
    addr:      fcl.withPrefix(SERVICE_ADDRESS),
    keyId:     KEY_INDEX,
    signature: signWithP256Sha3(signable.message),
  }),
});

/* 5️⃣  CADENCE 1.0 MINT TRANSACTION */
const cadence = `
import NonFungibleToken from 0xNonFungibleToken
import KintaGenNFT      from 0xKintaGenNFT
import MetadataViews    from 0xMetadataViews

transaction(recipient: Address, agent: String, outputCID: String, runHash: String) {

    let minter: &KintaGenNFT.Minter
    let recipientCollection: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        // obtain collection data once
        let data = KintaGenNFT
            .resolveContractView(
                resourceType: nil,
                viewType: Type<MetadataViews.NFTCollectionData>()
            )! as! MetadataViews.NFTCollectionData

        // borrow minter from service-account storage
        self.minter = signer.storage
            .borrow<&KintaGenNFT.Minter>(from: KintaGenNFT.MinterStoragePath)
            ?? panic("Minter not found in service account")

        // Cadence 1.0 way: account.capabilities.borrow
        self.recipientCollection = getAccount(recipient)
            .capabilities
            .borrow<&{NonFungibleToken.Receiver}>(data.publicPath)
            ?? panic("Recipient has no NFT receiver capability")
    }

    execute {
        let nft <- self.minter.mint(agent: agent, outputCID: outputCID, runHash: runHash)
        let id = nft.id
        self.recipientCollection.deposit(token: <-nft)
        log("Minted KintaGenNFT with ID ".concat(id.toString()))
    }
}
`;

/* 6️⃣  JS WRAPPER */
export async function mintNFT({ recipient, agent, outputCID, runHash }) {
  const txId = await fcl.mutate({
    cadence,
    args: (arg, t) => [
      arg(recipient, t.Address),
      arg(agent,     t.String),
      arg(outputCID, t.String),
      arg(runHash,   t.String),
    ],
    proposer: authorization,
    payer:    authorization,
    authorizations: [authorization],
    limit: 999,
  });

  console.log("Submitted transaction:", txId);
  const sealed = await fcl.tx(txId).onceSealed();
  console.log("Transaction sealed →", sealed.statusString);
  return sealed;
}

/* 7️⃣  QUICK TEST */
mintNFT({
  recipient: fcl.withPrefix(SERVICE_ADDRESS),  // replace with another address if desired
  agent:     "AgentName",
  outputCID: "QmSomeCID",
  runHash:   "SomeRunHash",
}).catch(console.error);
