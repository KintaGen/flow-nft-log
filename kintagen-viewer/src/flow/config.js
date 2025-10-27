// src/flow/config.js

import { config } from "@onflow/fcl";

// --- The Address of your KintaGenNFT contract on Testnet ---
// This is the address from your successful deployment.
const KINTAGEN_NFT_ADDRESS = "0x4971e1983b20b758";

// --- Standard Flow Contract Addresses on Testnet ---
const NON_FUNGIBLE_TOKEN_ADDRESS = "0x631e88ae7f1d7c20";
const METADATA_VIEWS_ADDRESS = "0x631e88ae7f1d7c20"; // ViewResolver is part of this

config({
  // 1. Point FCL to the Flow Testnet REST API endpoint
  "accessNode.api": "https://rest-testnet.onflow.org",
  
  // 2. Point FCL to the Testnet wallet discovery service. This allows
  // real wallets like Blocto, Lilico, etc., to connect to your app.
  "discovery.wallet": "https://fcl-discovery.onflow.org/testnet/authn",
  
  // 3. Set up aliases for our contracts using their Testnet addresses
  "0xKintaGenNFT": KINTAGEN_NFT_ADDRESS,
  "0xNonFungibleToken": NON_FUNGIBLE_TOKEN_ADDRESS,
  "0xViewResolver": METADATA_VIEWS_ADDRESS,
  "0xMetadataViews": METADATA_VIEWS_ADDRESS,
});