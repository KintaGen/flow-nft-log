import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "KintaGenLogScheduler"

/// Schedule a grant report reminder entry for a specific project NFT.
transaction(
    nftID: UInt64,
    delaySeconds: UFix64,
    dueTimestamp: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    note: Optional<String>,
    summaryCID: Optional<String>
) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let future = getCurrentBlock().timestamp + delaySeconds

        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        let payload: {String: AnyStruct} = {
            "action": "grant-reminder",
            "nftID": nftID,
            "dueTimestamp": dueTimestamp,
            "agent": "Grant Reminder Bot",
            "cid": (summaryCID ?? "n/a"),
            "note": (note ?? "")
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

        log(
            "Scheduled grant reminder for NFT "
                .concat(nftID.toString())
                .concat(" at ")
                .concat(future.toString())
        )
    }
}
