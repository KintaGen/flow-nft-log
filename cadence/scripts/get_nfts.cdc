import NonFungibleToken from 0x631e88ae7f1d7c20
import KintaGenNFT from 0x3c16354a3859c81b

access(all) fun main(address: Address): [UInt64]? {
    log("--- Starting NFT Check on Testnet ---")
    log("Target Address: ".concat(address.toString()))
    

    let account = getAccount(address)
    let collectionPath = KintaGenNFT.CollectionPublicPath
    log("Checking for collection at public path: ".concat(collectionPath.toString()))

    let collectionCap = account.capabilities.get<&{NonFungibleToken.CollectionPublic}>(collectionPath)
    
    if collectionCap == nil {
        log("!!! FAILURE: Capability is nil. The public link does not exist at all.")
        return nil
    }
    log("✅ SUCCESS: Found a capability at the path.")

    if !collectionCap!.check() {
        log("!!! FAILURE: Capability.check() failed. The link is broken or points to the wrong type.")
        return nil
    }
    log("✅ SUCCESS: Capability link is valid.")

    let collection = collectionCap!.borrow() ?? panic("Could not borrow collection.")
    log("✅ SUCCESS: Borrowed collection reference.")
    
    let ids = collection.getIDs()

    // --- CORRECTED ---
    // An array does not have a .toString() method.
    // We can just log the array directly.
    log("Found NFT IDs:")
    log(ids)
    
    log("--- Check Complete ---")

    return ids
}