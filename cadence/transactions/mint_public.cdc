import KintaGenNFT from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6

transaction(agent: String, outputCID: String, runHash: String) {
    prepare(signer: auth(BorrowValue) &Account) {
        let vault: auth(FungibleToken.Withdraw) &FlowToken.Vault =
            signer.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Missing FlowToken Vault. Run setup_user.cdc first.")

        let payment <- vault.withdraw(amount: 1.00)

        let nft <- KintaGenNFT.publicMint(
            payment: <- payment,
            agent: agent,
            outputCID: outputCID,
            runHash: runHash
        )

        let collection = signer.storage
            .borrow<&KintaGenNFT.Collection>(from: /storage/kintagenNFTCollection)
            ?? panic("Missing KintaGenNFT Collection. Run setup_user.cdc first.")
        collection.deposit(token: <- nft)
    }
}
