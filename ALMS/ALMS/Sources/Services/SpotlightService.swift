import CoreSpotlight
import Foundation

struct SpotlightService {
    private static let domain = "com.alms.item"

    func index(_ item: Item, db: ALMSDatabase) {
        let subject = (try? SubjectRepository(db: db).fetchById(item.subjectId)) ?? nil
        let subjectCode = subject.flatMap { s -> String? in
            s.code?.isEmpty == false ? s.code : s.name
        }
        let unit = item.unitId.flatMap { id in
            (try? UnitRepository(db: db).fetchById(id)) ?? nil
        }

        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = subjectCode.map { "\($0): \(item.title)" } ?? item.title

        var descParts = [item.type.capitalized]
        if let u = unit { descParts.append(u.name) }
        if let due = item.dueDate { descParts.append("Due \(due)") }
        attrs.contentDescription = descParts.joined(separator: " · ")

        attrs.keywords = [item.type, subjectCode].compactMap { $0 }

        let searchItem = CSSearchableItem(
            uniqueIdentifier: item.id,
            domainIdentifier: Self.domain,
            attributeSet: attrs
        )
        searchItem.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([searchItem]) { _ in }
    }

    func deindex(itemId: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemId]) { _ in }
    }

    func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [Self.domain]) { _ in }
    }

    func reindexAll(db: ALMSDatabase) {
        let items = (try? ItemRepository(db: db).fetchAll(status: .active)) ?? []
        guard !items.isEmpty else { return }

        let subjectRepo = SubjectRepository(db: db)
        let unitRepo = UnitRepository(db: db)

        // Batch-resolve subjects and units to avoid N+1 DB queries.
        var subjectMap: [String: String] = [:]
        for id in Set(items.map(\.subjectId)) {
            if let s = (try? subjectRepo.fetchById(id)) ?? nil {
                subjectMap[id] = s.code?.isEmpty == false ? s.code! : s.name
            }
        }
        var unitMap: [String: String] = [:]
        for id in Set(items.compactMap(\.unitId)) {
            if let u = (try? unitRepo.fetchById(id)) ?? nil {
                unitMap[id] = u.name
            }
        }

        let searchItems: [CSSearchableItem] = items.map { item in
            let subjectCode = subjectMap[item.subjectId]
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = subjectCode.map { "\($0): \(item.title)" } ?? item.title

            var descParts = [item.type.capitalized]
            if let unitName = item.unitId.flatMap({ unitMap[$0] }) { descParts.append(unitName) }
            if let due = item.dueDate { descParts.append("Due \(due)") }
            attrs.contentDescription = descParts.joined(separator: " · ")
            attrs.keywords = [item.type, subjectCode].compactMap { $0 }

            let searchItem = CSSearchableItem(
                uniqueIdentifier: item.id,
                domainIdentifier: Self.domain,
                attributeSet: attrs
            )
            searchItem.expirationDate = .distantFuture
            return searchItem
        }

        CSSearchableIndex.default().indexSearchableItems(searchItems) { _ in }
    }
}
