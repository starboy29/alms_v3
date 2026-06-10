import Foundation
@testable import ALMS

enum TestDatabase {
    static func make() throws -> ALMSDatabase {
        try ALMSDatabase(inMemory: true)
    }
}
