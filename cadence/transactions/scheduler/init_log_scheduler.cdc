import "KintaGenLogScheduler"
import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {

        if signer.storage.borrow<&AnyResource>(from: KintaGenLogScheduler.HandlerStoragePath) == nil {
            let handler <- KintaGenLogScheduler.createHandler()
            signer.storage.save(<-handler, to: KintaGenLogScheduler.HandlerStoragePath)
        }

        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(
                KintaGenLogScheduler.HandlerStoragePath
            )

        if signer.capabilities.get(KintaGenLogScheduler.HandlerPublicPath) == nil {
            let publicCap = signer.capabilities.storage
                .issue<&{FlowTransactionScheduler.TransactionHandler}>(
                    KintaGenLogScheduler.HandlerStoragePath
                )
            signer.capabilities.publish(publicCap, at: KintaGenLogScheduler.HandlerPublicPath)
        }

        if !signer.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            let managerCap = signer.capabilities.storage
                .issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(managerCap, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }
    }
}
