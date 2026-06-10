import Foundation

enum SyncStatus: String {
    case pending, created, updated, failed, retry, completed
    case permanentlyFailed = "permanently_failed"
}
