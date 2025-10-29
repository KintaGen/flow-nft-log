import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "KintaGenLogScheduler"

/// Schedule a daily summary log for a specific KintaGen project NFT.
///
/// Parameters:
/// - nftID: ID of the KintaGen project NFT.
/// - delaySeconds: Seconds in the future to execute the summary.
/// - windowSeconds: Sliding window of seconds to summarise (defaults to 24h).
/// - priority: 0 = High, 1 = Medium, anything else = Low.
/// - executionEffort: Gas limit for the scheduled transaction.
/// - metadataCID: Optional CID where a detailed summary artefact is stored ("n/a" if omitted).
transaction(
    nftID: UInt64,
    delaySeconds: UFix64,
    windowSeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    metadataCID: Optional<String>
) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let future = getCurrentBlock().timestamp + delaySeconds

        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        let payload: {String: AnyStruct} = {
            "action": "daily-summary",
            "nftID": nftID,
            "windowSeconds": windowSeconds,
            "agent": "KintaGen Scheduler",
            "cid": (metadataCID ?? "n/a")
        }

        let estimate = FlowTransactionScheduler.estimate(
            data: payload,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort
        )

        assert(
            estimate.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: estimate.error ?? "estimation failed"
        )

        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")

        let feeAmount = estimate.flowFee ?? 0.0
        let fees <- vaultRef.withdraw(amount: feeAmount) as! @FlowToken.Vault

        if !signer.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            let managerCap = signer.capabilities.storage
                .issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(managerCap, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }

        let handlerCap = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(
                KintaGenLogScheduler.HandlerStoragePath
            )

        let manager = signer.storage
            .borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(
                from: FlowTransactionSchedulerUtils.managerStoragePath
            ) ?? panic("Could not borrow scheduled transaction manager.")

        manager.schedule(
            handlerCap: handlerCap,
            data: payload,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled daily summary for NFT ".concat(nftID.toString()).concat(" at ").concat(future.toString()))
    }
}
