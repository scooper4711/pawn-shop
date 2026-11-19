import Foundation
import SharedLibraries
import TablesideSync
import Testing
@testable import PawnShopCore

/// What Settings › Sync says and offers (R10.5, R10.6).
@Suite struct SyncSettingsTextTests {
    @Test func saysWhetherTheLibrarySyncsAndWhyNot() {
        let statuses: [SyncStatus] = [.unsupported, .unavailable, .syncing, .upToDate, .paused, .storageFull,
                                      .failed("The disk is full.")]
        let summaries = statuses.map(SyncSettingsText.summary(of:))
        #expect(Set(summaries).count == statuses.count)
        #expect(summaries[0].contains("without iCloud") && summaries[1].contains("Sign in to iCloud"))
        #expect(summaries[4].contains("paused") && summaries[5].contains("iCloud is full"))
        #expect(summaries[6].hasSuffix("The disk is full."))
        #expect(!SyncSettingsText.explanation.isEmpty && !SyncSettingsText.keepingNote.isEmpty)
    }

    @Test func offersTheWaysToKeepPictures() {
        let choices = PictureKeeping.choices(including: .shown)
        #expect(choices.count == 6 && choices.first == .shown && choices.last == .everything)
        #expect(choices.map(\.title).contains { $0.contains("250") && $0.hasPrefix("Up to") })
        #expect(Set(choices.map(\.title)).count == 6)
        #expect(SyncSettingsText.size(ofBytes: 38_000_000).contains("38"))

        let other = PictureKeeping.upTo(750_000_000)
        #expect(PictureKeeping.choices(including: other)[3] == other)
        #expect(PictureKeeping.choices(including: .upTo(500_000_000)).count == 6)
    }

    @Test func mapsToTheToolkitsPolicyAndBack() {
        for keeping in PictureKeeping.choices(including: .upTo(1)) {
            #expect(PictureKeeping(keeping.policy) == keeping)
        }
        #expect(PictureKeeping(.onDemand(limit: nil)) == .shown && PictureKeeping.everything.policy == .everything)
        #expect(PictureKeeping.upTo(5).policy == .onDemand(limit: 5))
    }
}
