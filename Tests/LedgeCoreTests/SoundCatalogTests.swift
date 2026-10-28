import Testing
@testable import LedgeCore

@Test func catalogKeepsAudioFilesStripsExtensionsAndSorts() {
    let files = ["Submarine.aiff", ".DS_Store", "Glass.aiff", "README.txt", "Basso.AIFF", "x.caf"]
    #expect(SoundCatalog.names(fromFileNames: files) == ["Basso", "Glass", "Submarine", "x"])
}

@Test func resolvePrefersSelectionThenGlassThenFirst() {
    let available = ["Basso", "Glass", "Ping"]
    #expect(SoundCatalog.resolve(selected: "Ping", available: available) == "Ping")
    #expect(SoundCatalog.resolve(selected: "Gone", available: available) == "Glass")
    #expect(SoundCatalog.resolve(selected: nil, available: ["Basso", "Ping"]) == "Basso")
    #expect(SoundCatalog.resolve(selected: nil, available: []) == nil)
}
