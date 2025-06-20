// src/App.js

import React, { useState, useEffect } from 'react';
import * as fcl from "@onflow/fcl";
import './flow/config'; // Import FCL config
import KintaGenWorkflowViewer from './components/KintaGenWorkflowViewer'; // Import our new component

// The new Cadence script to discover all NFT IDs
const getAllNftIdsScript = `
  import KintaGenNFT from 0xKintaGenNFT

  access(all) fun main(ownerAddress: Address): [UInt64] {
      let owner = getAccount(ownerAddress)
      let collectionRef = owner.capabilities.get<&KintaGenNFT.Collection>(KintaGenNFT.CollectionPublicPath)
          .borrow()
          ?? panic("Could not borrow a reference to the KintaGenNFT Collection.")
      return collectionRef.getIDs()
  }
`;

function App() {
  const [nftIds, setNftIds] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // The address of the account that holds the main collection
  const collectionOwnerAddress = "0xf8d6e0586b0a20c7"; 

  // This useEffect runs once when the app loads to fetch all the IDs.
  useEffect(() => {
    const fetchAllIds = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const ids = await fcl.query({
          cadence: getAllNftIdsScript,
          args: (arg, t) => [arg(collectionOwnerAddress, t.Address)]
        });
        setNftIds(ids);
      } catch (err) {
        console.error("Error fetching all NFT IDs:", err);
        setError("Could not fetch the list of NFTs. Is the emulator running and the contract deployed?");
      } finally {
        setIsLoading(false);
      }
    };
    fetchAllIds();
  }, []); // Empty dependency array means this runs only once on mount

  return (
    <div className="container">
      <header>
        <h1>KintaGen On-Chain Workflow Explorer</h1>
        <p>Discovering all NFTs owned by the master account...</p>
      </header>
      
      {isLoading && <p>Loading all NFTs...</p>}
      {error && <p className="error">{error}</p>}

      <div className="workflows-list">
        {!isLoading && nftIds.length === 0 && (
          <p>No NFTs found in the collection. Mint one to get started!</p>
        )}
        
        {nftIds.map(id => (
          <KintaGenWorkflowViewer 
            key={id} 
            nftId={id} 
            ownerAddress={collectionOwnerAddress} 
          />
        ))}
      </div>
    </div>
  );
}

export default App;