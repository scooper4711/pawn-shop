import CloudKit
import Foundation

/// Turns custom pawns' records into CloudKit records and back (R10.2): the type `CustomPawn` in the zone `PawnShop`
/// of the suite's container, one per pawn with settings, named `pawn-<UUID>` after its creature, with the fields
/// `format`, `title` and `payload`. The image is the creature library's, which the toolkit syncs.
enum CustomPawnRecordCoder {
    static let zoneName = "PawnShop"
    static let recordType = "CustomPawn"
    static let recordPrefix = "pawn-"
    /// The layout of a record's fields. A record in a later layout isn't read, and its pawn here isn't sent over
    /// it; nothing of it is kept, so the version that raises this must make each device fetch again what its
    /// earlier versions passed over (tabletop-kit library sync design, "Records in CloudKit").
    static let format: Int64 = 1
    static let zone = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

    /// The record to save, over the server's last known copy when there is one, so the save is a change to it
    /// and not a conflict.
    static func record(for outgoing: OutgoingCustomPawn) -> CKRecord {
        let record = outgoing.systemFields.flatMap(record(withSystemFields:))
            ?? CKRecord(recordType: recordType, recordID: recordID(of: outgoing.id))
        record["format"] = format
        record["title"] = outgoing.title
        record["payload"] = outgoing.payload
        return record
    }

    /// What a record from the server means to the custom pawns; nil when it isn't one of theirs. A record in a
    /// later layout comes back with an empty payload, which is noted as unreadable.
    static func change(from record: CKRecord) -> CustomPawnChange? {
        guard record.recordType == recordType, let id = pawnID(of: record.recordID) else { return nil }
        let isReadable = record["format"] as? Int64 ?? format <= format
        let payload = isReadable ? record["payload"] as? Data ?? Data() : Data()
        return .saved(RemoteCustomPawn(id: id, payload: payload, systemFields: systemFields(of: record)))
    }

    static func recordID(of id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: recordPrefix + id.uuidString, zoneID: zone)
    }

    /// The pawn a record ID names; nil for a record of another zone or with another kind of name.
    static func pawnID(of recordID: CKRecord.ID) -> UUID? {
        guard recordID.zoneID == zone, recordID.recordName.hasPrefix(recordPrefix) else { return nil }
        return UUID(uuidString: String(recordID.recordName.dropFirst(recordPrefix.count)))
    }

    /// A record's system fields, archived: its change tag, so the next save of it doesn't conflict with itself.
    static func systemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    /// The server's copy of a record, with its system fields only; nil when `data` isn't an archive of them.
    static func record(withSystemFields data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}
