import Foundation
import Testing
@testable import LedgeCore

@Test func theLanguageListMatchesTheTranslationFolders() throws {
    let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")
    let folders = try FileManager.default.contentsOfDirectory(atPath: resources.path)
        .filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(".lproj".count)) }
    #expect(Set(AppLanguage.all.map(\.code)) == Set(folders))
}

@Test func everyLanguageHasANativeName() {
    #expect(AppLanguage.all.allSatisfy { !$0.nativeName.isEmpty })
    #expect(AppLanguage.all.first { $0.code == "ru" }?.nativeName == "Русский")
    #expect(AppLanguage.all.first { $0.code == "ja" }?.nativeName == "日本語")
}

@Test func noStoredOverrideMeansTheSystemLanguage() {
    #expect(AppLanguage.override(stored: nil) == nil)
    #expect(AppLanguage.override(stored: []) == nil)
}

@Test func aStoredKnownLanguageIsTheOverride() {
    #expect(AppLanguage.override(stored: ["de"]) == "de")
    #expect(AppLanguage.override(stored: ["pt-BR", "en"]) == "pt-BR")
}

@Test func anUnknownStoredLanguageIsIgnored() {
    #expect(AppLanguage.override(stored: ["xx"]) == nil)
}

@Test func choosingTheSystemClearsTheOverride() {
    #expect(AppLanguage.valueToStore(for: nil) == nil)
    #expect(AppLanguage.valueToStore(for: "fr") == ["fr"])
    #expect(AppLanguage.valueToStore(for: "nonsense") == nil)
}
