import CoreGraphics
import Foundation
import SharedLibraries
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

/// A device's worth of Pawn Shop for the sync tests: a library in a folder of its own.
struct SyncDevice {
    let library: PawnLibrary

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
    }

    /// Adds a pawn placed off center, so it has settings of Pawn Shop's own to sync.
    @discardableResult
    func addHero(named name: String = "Hero") throws -> Pawn {
        try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: name, focus: CGPoint(x: 0.2, y: 0.8)))
    }

    /// Gives this device a pawn's creature and image, as the creature library's own sync brings them.
    func receiveCreature(of pawn: Pawn) throws {
        guard case .custom(let art) = pawn.art else { return }
        let creature = NewCreature(pawn: pawn, size: CreatureSize(pawn.size), image: Data("png".utf8))
        try library.addCreature(creature, imageFile: art.imageFile)
        try library.refresh()
    }

    /// Sets when the user last changed a pawn's settings, as though the change were made then.
    func setModified(_ seconds: Double, of pawn: Pawn) {
        library.own.customPawnsModified[pawn.id.uuidString] = seconds
    }

    /// Sends a pawn's record, as though the server took it, and gives it as another device then fetches it.
    func send(_ pawn: Pawn, fields: String = "fields 1") throws -> RemoteCustomPawn {
        let outgoing = try #require(library.outgoingCustomPawn(pawn.id))
        try library.markSent(outgoing, systemFields: Data(fields.utf8))
        return RemoteCustomPawn(id: outgoing.id, payload: outgoing.payload, systemFields: Data(fields.utf8))
    }

    func tags(of pawn: Pawn) -> [String]? {
        library.pawn(id: pawn.id)?.tags
    }
}

/// What custom pawns' settings have to send, and how another device's records are merged in (R10.2).
@Suite struct CustomPawnSyncingTests {
    let mac: SyncDevice
    let pad: SyncDevice

    init() throws {
        mac = try SyncDevice()
        pad = try SyncDevice()
    }

    @Test func sendsNewSettingsOnceAndAgainWhenTheyChange() throws {
        let hero = try mac.addHero()
        #expect(mac.library.customPawnCandidates() == CustomPawnCandidates(saves: [hero.id]))
        let outgoing = try #require(mac.library.outgoingCustomPawn(hero.id))
        #expect(outgoing.title == "Hero" && outgoing.systemFields == nil)

        try mac.library.markSent(outgoing, systemFields: Data("fields 1".utf8))
        #expect(mac.library.customPawnCandidates().isEmpty && mac.library.outgoingCustomPawn(hero.id) == nil)

        try mac.library.correctTags(["sword"], of: hero.id)
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
        #expect(mac.library.outgoingCustomPawn(hero.id)?.systemFields == Data("fields 1".utf8))
        #expect(mac.library.outgoingCustomPawn(UUID()) == nil)
    }

    @Test func leavesTheNameToTheCreatureLibrary() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        let changes = mac.library.customPawnChanges
        try mac.library.rename(hero.id, to: "Heroine")
        #expect(mac.library.pawn(id: hero.id)?.name == "Heroine")
        #expect(mac.library.customPawnCandidates().isEmpty && mac.library.customPawnChanges == changes)
        let payload = try #require(mac.library.own.pawnSettings[hero.id.uuidString].map {
            try CustomPawnPayload(id: hero.id, settings: $0, modified: 0).encoded()
        })
        #expect(String(bytes: payload, encoding: .utf8)?.contains("name") == false)
    }

    @Test func aPawnWithTheDefaultsHasNothingToSend() throws {
        let plain = try mac.library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: "Plain"))
        #expect(mac.library.customPawnCandidates().isEmpty && mac.library.outgoingCustomPawn(plain.id) == nil)
        #expect(mac.library.own.pawnSettings.isEmpty)
    }

    @Test func keepsWhatTheServerHoldsBetweenLaunches() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        try mac.library.setCustomPawnAccount("user 1")
        let reopened = try PawnLibrary(folder: mac.library.folder)
        #expect(reopened.customPawnCandidates().isEmpty && reopened.customPawnAccount == "user 1")
    }

    @Test func aChangeMadeWhileARecordIsOnItsWayIsStillSent() throws {
        let hero = try mac.addHero()
        let outgoing = try #require(mac.library.outgoingCustomPawn(hero.id))
        try mac.library.correctTags(["sword"], of: hero.id)
        try mac.library.markSent(outgoing, systemFields: Data("fields 1".utf8))
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
    }

    @Test func sendsTheDeletionOfAPawnTheServerHolds() throws {
        let hero = try mac.addHero(), unsent = try mac.addHero(named: "Unsent")
        _ = try mac.send(hero)
        try mac.library.remove([hero.id, unsent.id])
        #expect(mac.library.customPawnCandidates() == CustomPawnCandidates(deletions: [hero.id]))
        try mac.library.markDeleted(hero.id)
        #expect(mac.library.customPawnCandidates().isEmpty)
    }

    @Test func sendsEverythingAgainOnceTheServerIsForgotten() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        try mac.library.forgetSystemFields(of: hero.id)
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
        #expect(mac.library.outgoingCustomPawn(hero.id)?.systemFields == nil)

        _ = try mac.send(hero)
        try mac.library.forgetCustomPawnServer()
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
    }

    @Test func takesTheSettingsAnotherDeviceMade() throws {
        let hero = try mac.addHero()
        try mac.library.correctTags(["Sword"], of: hero.id)
        try pad.receiveCreature(of: hero)
        #expect(try pad.library.applyRemote([.saved(try mac.send(hero))]))

        let arrived = try #require(pad.library.pawn(id: hero.id))
        #expect(arrived.name == "Hero" && arrived.tags == ["sword"] && arrived.tagsCorrected && arrived.isCustom)
        #expect(arrived.art == mac.library.pawn(id: hero.id)?.art, "placed as on the Mac")
        #expect(pad.library.customPawnCandidates().isEmpty, "what arrived isn't sent back")
        #expect(try PawnLibrary(folder: pad.library.folder).pawn(id: hero.id) == arrived)
    }

    @Test func keepsSettingsThatArriveBeforeTheirCreature() throws {
        let hero = try mac.addHero()
        #expect(try pad.library.applyRemote([.saved(try mac.send(hero))]))
        #expect(pad.library.pawn(id: hero.id) == nil && pad.library.customPawnCandidates().isEmpty)
        try pad.receiveCreature(of: hero)
        #expect(pad.library.pawn(id: hero.id)?.art == hero.art)
    }

    @Test func aRecordItKnowsChangesNothing() throws {
        let hero = try mac.addHero()
        let record = try mac.send(hero)
        try pad.library.applyRemote([.saved(record)])
        #expect(try !pad.library.applyRemote([.saved(record)]))
        #expect(try !mac.library.applyRemote([.saved(record)]), "its own record, fetched back")
        #expect(mac.library.customPawnCandidates().isEmpty && pad.library.customPawnCandidates().isEmpty)
    }

    @Test func aRecordForAPawnRemovedHereDoesNotBringItsSettingsBack() throws {
        let hero = try mac.addHero()
        let record = try mac.send(hero)
        try mac.library.remove([hero.id])
        #expect(try !mac.library.applyRemote([.saved(record)]))
        #expect(mac.library.pawn(id: hero.id) == nil && mac.library.own.pawnSettings.isEmpty)
        #expect(mac.library.customPawnCandidates().deletions == [hero.id])
    }

    @Test func theLaterOfTwoChangesWins() throws {
        let hero = try mac.addHero()
        try pad.receiveCreature(of: hero)
        try pad.library.applyRemote([.saved(try mac.send(hero))])
        try mac.library.correctTags(["mac"], of: hero.id)
        try pad.library.correctTags(["pad"], of: hero.id)
        mac.setModified(200, of: hero)
        pad.setModified(100, of: hero)

        let fromMac = try mac.send(hero, fields: "fields 2")
        #expect(try pad.library.applyRemote([.saved(fromMac)]))
        #expect(pad.tags(of: hero) == ["mac"] && pad.library.customPawnCandidates().isEmpty)

        try pad.library.correctTags(["pad again"], of: hero.id)
        pad.setModified(300, of: hero)
        #expect(try !pad.library.applyRemote([.saved(fromMac)]), "known content")
        try mac.library.correctTags(["mac again"], of: hero.id)
        mac.setModified(250, of: hero)
        #expect(try !pad.library.applyRemote([.saved(try mac.send(hero, fields: "fields 3"))]))
        #expect(pad.tags(of: hero) == ["pad again"])
        #expect(pad.library.outgoingCustomPawn(hero.id)?.systemFields == Data("fields 3".utf8),
                "the settings here are sent over the record they beat")
    }

    @Test func removesSettingsAnotherDeviceRemovedUnlessTheyChangedHere() throws {
        let hero = try mac.addHero(), villain = try mac.addHero(named: "Villain")
        try pad.receiveCreature(of: hero)
        try pad.receiveCreature(of: villain)
        try pad.library.applyRemote([.saved(try mac.send(hero)), .saved(try mac.send(villain))])
        try pad.library.correctTags(["changed"], of: villain.id)

        #expect(try pad.library.applyRemote([.deleted(hero.id), .deleted(villain.id), .deleted(UUID())]))
        #expect(pad.library.own.pawnSettings.keys.sorted() == [villain.id.uuidString])
        #expect(pad.library.pawn(id: hero.id)?.art != hero.art, "back to the defaults until its creature goes too")
        #expect(pad.tags(of: villain) == ["changed"])
        #expect(pad.library.customPawnCandidates() == CustomPawnCandidates(saves: [villain.id]))
        #expect(pad.library.outgoingCustomPawn(villain.id)?.systemFields == nil, "sent as new")
    }

    @Test func doesNotSendOverARecordItCannotRead() throws {
        let hero = try mac.addHero()
        try pad.receiveCreature(of: hero)
        try pad.library.applyRemote([.saved(try mac.send(hero))])
        let later = RemoteCustomPawn(id: hero.id, payload: Data(#"{"scaling":"stretch"}"#.utf8),
                                     systemFields: Data("fields 2".utf8))
        #expect(try !pad.library.applyRemote([.saved(later)]))
        try pad.library.correctTags(["changed here"], of: hero.id)
        #expect(pad.library.customPawnCandidates().isEmpty && pad.library.outgoingCustomPawn(hero.id) == nil)

        try mac.library.correctTags(["readable again"], of: hero.id)
        mac.setModified(.greatestFiniteMagnitude, of: hero)
        #expect(try pad.library.applyRemote([.saved(try mac.send(hero, fields: "fields 3"))]))
        #expect(pad.tags(of: hero) == ["readable again"])
    }

    @Test func readsARecordSavedWhenItStillHeldTheNameAndSize() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        let old = #"{"focusX":0.25,"focusY":0.5,"id":"\#(hero.id.uuidString)","modified":5,"name":"Old Name","#
            + #""scaling":"fit","showsName":false,"size":"large","tagModel":"","tags":["axe"],"tagsCorrected":true}"#
        #expect(try mac.library.applyRemote([.saved(RemoteCustomPawn(id: hero.id, payload: Data(old.utf8),
                                                                     systemFields: Data("fields 2".utf8)))]))
        let pawn = try #require(mac.library.pawn(id: hero.id))
        #expect(pawn.name == "Hero" && pawn.size == .medium && pawn.tags == ["axe"])
        #expect(pawn.art == .custom(CustomArt(imageFile: "\(hero.id.uuidString).png", focus: CGPoint(x: 0.25, y: 0.5),
                                               showsName: false, scaling: .fit)))
    }

    @Test func readsALibraryFileSavedBeforeChangesWereTimed() throws {
        let json = #"{"version":1,"customPawns":[],"hidden":[],"importedFiles":{},"readAgain":{"a":"b"}}"#
        let own = try JSONDecoder().decode(OwnLibrary.self, from: Data(json.utf8))
        #expect(own.customPawnsModified.isEmpty && own.pawnSettings.isEmpty && own.readAgain == ["a": "b"])
        #expect(try JSONDecoder().decode(OwnLibrary.self, from: Data("{}".utf8)) == OwnLibrary())
    }

    @Test func aLedgerThatCannotBeReadCountsAsEmpty() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        try Data("not json".utf8).write(to: mac.library.folder.appendingPathComponent(CustomPawnLedger.fileName))
        #expect(try PawnLibrary(folder: mac.library.folder).customPawnCandidates().saves == [hero.id])
    }

    @Test func timesTheChangesTaggingMakes() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        let before = mac.library.customPawnChanges
        mac.library.setTags(["staff"], by: "model 1", of: hero.id)
        try mac.library.save()
        #expect(mac.library.customPawnChanges > before)
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
        try mac.library.remove([hero.id])
        #expect(mac.library.own.customPawnsModified.isEmpty)
    }
}
