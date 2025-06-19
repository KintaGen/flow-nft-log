// Path: kintagen-viewer/src/App.js

import React, { useState } from 'react';
import * as fcl from "@onflow/fcl";
import './flow/config'; // Import the FCL configuration to apply it

// The Cadence script to read the workflow story is embedded here
const getWorkflowStoryScript = `
  import ViewResolver from 0xViewResolver
  import KintaGenNFT from 0xKintaGenNFT

  access(all) fun main(ownerAddress: Address, nftID: UInt64): [KintaGenNFT.WorkflowStepView]? {
      let owner = getAccount(ownerAddress)
      
      // 1. Get the capability. This returns an optional: Capability?
      let collectionCap = owner.capabilities.get<&{ViewResolver.ResolverCollection}>(KintaGenNFT.CollectionPublicPath)

      // 2. Explicitly check if the optional is nil.
      if collectionCap == nil {
          panic("Account does not have the required public KintaGenNFT resolver collection capability.")
      }

      // 3. Now we can safely borrow the reference.
      let collectionRef = collectionCap!.borrow()
          ?? panic("Could not borrow a reference to the Collection.")
          
      let resolver = collectionRef.borrowViewResolver(id: nftID)
          ?? panic("Could not borrow view resolver for KintaGenNFT.")
          
      let storyView = resolver.resolveView(Type<KintaGenNFT.WorkflowStepView>())
      
      return storyView as? [KintaGenNFT.WorkflowStepView]
  }
`;

function App() {
  const [nftId, setNftId] = useState(""); // User will input the ID
  const [story, setStory] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  // The owner is our single emulator-account for this test
  const ownerAddress = "0xf8d6e0586b0a20c7"; 

  const fetchStory = async () => {
    if (!nftId) {
      setError("Please enter an NFT ID.");
      return;
    }
    setIsLoading(true);
    setError(null);
    setStory(null);

    try {
      const result = await fcl.query({
        cadence: getWorkflowStoryScript,
        args: (arg, t) => [
          arg(ownerAddress, t.Address),
          arg(nftId, t.UInt64)
        ]
      });
      setStory(result);
    } catch (err) {
      console.error(err);
      setError("Failed to fetch workflow story. Check the console and ensure the NFT ID is correct and the account is set up.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="container">
      <header>
        <h1>KintaGen NFT Workflow Viewer</h1>
        <p>Enter the ID of a KintaGenNFT to see its on-chain, auditable history.</p>
      </header>

      <div className="input-group">
        <input
          type="text"
          value={nftId}
          onChange={(e) => setNftId(e.target.value)}
          placeholder="Enter KintaGenNFT ID (e.g., 177021372071936)"
        />
        <button onClick={fetchStory} disabled={isLoading}>
          {isLoading ? 'Loading...' : 'Fetch Story'}
        </button>
      </div>

      {error && <p className="error">{error}</p>}

      {story && story.length > 0 && (
        <div className="timeline">
          <h2>Workflow for NFT #{nftId}</h2>
          {story.map((step) => (
            <div key={step.stepNumber} className="timeline-item">
              <div className="timeline-step-number">{step.stepNumber}</div>
              <div className="timeline-content">
                <h3>{step.action}</h3>
                <p><strong>Agent:</strong> {step.agent}</p>
                <p><strong>Result CID:</strong> <span className="cid">{step.resultCID}</span></p>
                <p><small>Timestamp: {new Date(parseFloat(step.timestamp) * 1000).toLocaleString()}</small></p>
              </div>
            </div>
          ))}
        </div>
      )}
      {story === null && !isLoading && !error && (
        <p className="placeholder">Enter an ID and click "Fetch Story" to begin.</p>
      )}
      {story && story.length === 0 && (
         <div className="timeline">
          <h2>Workflow for NFT #{nftId}</h2>
          <p>This NFT exists but has no log entries yet. This is its initial state.</p>
        </div>
      )}
    </div>
  );
}

export default App;