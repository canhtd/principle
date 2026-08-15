import Testing

@testable import PrincipleCore

@Suite("PrincipleCore smoke")
struct SmokeTests {
    @Test("App metadata is populated")
    func metadataIsPopulated() {
        #expect(!PrincipleInfo.version.isEmpty)
        #expect(PrincipleInfo.bundleIdentifier == "com.danny.principle")
    }

    @Test("Every section carries a label and an icon")
    func sectionsAreComplete() {
        #expect(AppSection.allCases == [.chat, .favorites])
        for section in AppSection.allCases {
            #expect(!section.title.isEmpty)
            #expect(!section.systemImage.isEmpty)
        }
    }
}
