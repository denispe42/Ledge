import Foundation
import Testing

/// Every language file must stay in step with English: the same keys (a missing translation silently shows English,
/// which is how a gap goes unnoticed), no key twice, and the same placeholders (%d, %@) in every translation.
private let resources: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources")

private func entries(_ language: String, file: String = "Localizable") throws -> [(key: String, value: String)] {
    let text = try String(contentsOf: resources.appendingPathComponent("\(language).lproj/\(file).strings"), encoding: .utf8)
    return text.split(separator: "\n").compactMap { line in
        // "key" = "value";
        let parts = line.components(separatedBy: "\" = \"")
        guard parts.count == 2, line.hasPrefix("\""), line.hasSuffix("\";") else { return nil }
        return (String(parts[0].dropFirst()), String(parts[1].dropLast(2)))
    }
}

private func languages() throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: resources.path)
        .filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(".lproj".count)) }.sorted()
}

private func placeholders(_ text: String) -> [String] {
    text.components(separatedBy: "%").dropFirst().compactMap { $0.first.map { String($0) } }.sorted()
}

@Test func thereAreManyLanguages() throws {
    let all = try languages()
    #expect(all.count >= 12)
    #expect(all.contains("en") && all.contains("ru"))
}

@Test func everyLanguageHasTheSameKeysAsEnglish() throws {
    let english = Set(try entries("en").map(\.key))
    #expect(!english.isEmpty)
    for language in try languages() where language != "en" {
        let keys = Set(try entries(language).map(\.key))
        #expect(english.subtracting(keys).isEmpty, "missing in \(language): \(english.subtracting(keys).sorted())")
        #expect(keys.subtracting(english).isEmpty, "unknown in \(language): \(keys.subtracting(english).sorted())")
    }
}

@Test func noKeyIsDefinedTwice() throws {
    for language in try languages() {
        let all = try entries(language).map(\.key)
        #expect(all.count == Set(all).count, "duplicate keys in \(language)")
    }
}

@Test func translationsKeepThePlaceholders() throws {
    let english = Dictionary(uniqueKeysWithValues: try entries("en").map { ($0.key, $0.value) })
    for language in try languages() where language != "en" {
        for (key, value) in try entries(language) {
            #expect(placeholders(value) == placeholders(english[key] ?? ""), "\(language): placeholders differ for \"\(key)\"")
        }
    }
}

@Test func noTranslationIsEmpty() throws {
    for language in try languages() {
        for (key, value) in try entries(language) { #expect(!value.isEmpty, "\(language): empty text for \"\(key)\"") }
    }
}

@Test func everyLanguageTranslatesTheCameraPermissionText() throws {
    for language in try languages() {
        let found = try entries(language, file: "InfoPlist").first { $0.key == "NSCameraUsageDescription" }
        #expect(found != nil, "no camera permission text in \(language)")
    }
}
