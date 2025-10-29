import "FlowTransactionScheduler"
import PublicKintaGenNFTv3 from 0xPublicKintaGenNFTv3

access(all) contract KintaGenLogScheduler {

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {

        access(FlowTransactionScheduler.Execute)
        fun executeTransaction(id: UInt64, data: AnyStruct?) {
            pre {
                data != nil: "Scheduler payload missing."
            }

            let payload = data! as! {String: AnyStruct}

            let nftID = payload["nftID"] as? UInt64
                ?? panic("Scheduler payload missing nftID.")
            let action = payload["action"] as? String
                ?? panic("Scheduler payload missing action.")

            var agent = "KintaGen Scheduler"
            if let overrideAgent = payload["agent"] {
                agent = overrideAgent as! String
            }

            var cid = "n/a"
            if let cidPayload = payload["cid"] {
                cid = cidPayload as! String
            }

            var title = ""
            var description = ""

            switch action {
            case "daily-summary":
                var windowSeconds: UFix64 = 86400.0
                if let window = payload["windowSeconds"] {
                    windowSeconds = window as! UFix64
                }

                let stats = PublicKintaGenNFTv3.getDailySummaryStats(
                    nftID: nftID,
                    windowSeconds: windowSeconds
                )

                let entries = stats["entries"] as! Int
                let totalEntries = stats["totalEntries"] as! Int
                let startTs = stats["startTimestamp"] as! UFix64
                let endTs = stats["endTimestamp"] as! UFix64
                let projectName = stats["projectName"] as! String

                title = "Daily Summary – ".concat(projectName)
                description =
                    "Entries in last "
                    .concat(windowSeconds.toString())
                    .concat(" seconds: ")
                    .concat(entries.toString())
                    .concat(" | Total Entries: ")
                    .concat(totalEntries.toString())
                    .concat(" | Window: ")
                    .concat(startTs.toString())
                    .concat(" → ")
                    .concat(endTs.toString())

            case "grant-reminder":
                let dueTimestamp = payload["dueTimestamp"] as? UFix64
                    ?? getCurrentBlock().timestamp

                title = "Grant Report Reminder"
                description =
                    "Grant report approaching. Target submission timestamp: "
                    .concat(dueTimestamp.toString())
                    .concat(". Please review project records.")

                if let note = payload["note"] {
                    description = description.concat(" Note: ").concat(note as! String)
                }

            default:
                panic("Unsupported scheduled action: ".concat(action))
            }

            PublicKintaGenNFTv3.appendAutomatedLog(
                nftID: nftID,
                agent: agent,
                title: title,
                description: description,
                cid: cid
            )
        }

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return KintaGenLogScheduler.HandlerStoragePath
                case Type<PublicPath>():
                    return KintaGenLogScheduler.HandlerPublicPath
                default:
                    return nil
            }
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    init() {
        self.HandlerStoragePath = /storage/kintagenLogSchedulerHandler
        self.HandlerPublicPath = /public/kintagenLogSchedulerHandler
    }
}
