import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6

transaction(recipient: Address, amount: UFix64) {
    prepare(signer: auth(BorrowValue) &Account) {
        let fromVault = signer.storage.borrow<&FlowToken.Vault>(/storage/flowTokenVault)
            ?? panic("Sender missing FlowToken Vault")
        let toVault = getAccount(recipient)
            .capabilities
            .get<&FlowToken.Vault>(/public/flowTokenReceiver)
            .borrow()
            ?? panic("Recipient missing FlowToken receiver")

        let payment <- fromVault.withdraw(amount: amount)
        toVault.deposit(from: <- payment)
    }
}
