import XCTest
@testable import Wallps

@MainActor
final class WallpaperLibraryTests: XCTestCase {
    private var root: URL!
    private var library: WallpaperLibrary!

    override func setUp() async throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WallpsTests-\(UUID().uuidString)")
        library = WallpaperLibrary(rootURL: root)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeItem(title: String = "Test", filename: String = "video.mp4") -> WallpaperItem {
        WallpaperItem(
            id: UUID(),
            title: title,
            videoFilename: filename,
            thumbnailFilename: nil,
            duration: 10,
            pixelWidth: 3840,
            pixelHeight: 2160,
            source: .local,
            dateAdded: Date()
        )
    }

    private func writeVideoFile(named filename: String) throws {
        try FileManager.default.createDirectory(at: library.videosURL, withIntermediateDirectories: true)
        try Data("not really a video".utf8).write(to: library.videosURL.appendingPathComponent(filename))
    }

    func testRoundTripsThroughDisk() throws {
        try writeVideoFile(named: "video.mp4")
        let item = makeItem()
        library.add(item)

        let reloaded = WallpaperLibrary(rootURL: root)
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.id, item.id)
        XCTAssertEqual(reloaded.items.first?.title, "Test")
    }

    /// A half-deleted library should not show tiles that can never play.
    func testDropsEntriesWhoseVideoIsGone() throws {
        try writeVideoFile(named: "present.mp4")
        library.add(makeItem(title: "Present", filename: "present.mp4"))
        library.add(makeItem(title: "Missing", filename: "missing.mp4"))

        let reloaded = WallpaperLibrary(rootURL: root)
        reloaded.load()
        XCTAssertEqual(reloaded.items.map(\.title), ["Present"])
    }

    func testLoadingAnAbsentLibraryIsNotAnError() {
        library.load()
        XCTAssertTrue(library.items.isEmpty)
        XCTAssertNil(library.lastError)
    }

    func testLookupByIDString() throws {
        try writeVideoFile(named: "video.mp4")
        let item = makeItem()
        library.add(item)

        XCTAssertEqual(library.item(withIDString: item.id.uuidString)?.id, item.id)
        XCTAssertNil(library.item(withIDString: "not-a-uuid"))
        XCTAssertNil(library.item(withIDString: nil))
    }

    func testCatalogMembershipTracksCatalogIDNotTitle() throws {
        var item = makeItem(title: "Aurora")
        item.catalogID = "aurora-01"
        library.add(item)

        XCTAssertTrue(library.containsCatalogItem(id: "aurora-01"))
        // A different catalog entry that happens to share a title is not owned.
        XCTAssertFalse(library.containsCatalogItem(id: "aurora-02"))
    }

    func testDeleteRemovesFilesAndIndexEntry() throws {
        try writeVideoFile(named: "video.mp4")
        let item = makeItem()
        library.add(item)

        library.delete(item)
        XCTAssertTrue(library.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.videoURL(for: item).path))
    }
}

final class WallpaperItemFormattingTests: XCTestCase {
    private func item(width: Int, height: Int, duration: TimeInterval) -> WallpaperItem {
        WallpaperItem(
            id: UUID(), title: "T", videoFilename: "v.mp4", thumbnailFilename: nil,
            duration: duration, pixelWidth: width, pixelHeight: height,
            source: .local, dateAdded: Date()
        )
    }

    func testResolutionLabels() {
        XCTAssertEqual(item(width: 3840, height: 2160, duration: 1).resolutionLabel, "4K")
        XCTAssertEqual(item(width: 1920, height: 1080, duration: 1).resolutionLabel, "1080p")
        XCTAssertEqual(item(width: 640, height: 480, duration: 1).resolutionLabel, "640×480")
        XCTAssertEqual(item(width: 0, height: 0, duration: 1).resolutionLabel, "—")
    }

    /// Portrait 4K is still 4K: the short side is what qualifies it.
    func testPortraitVideoIsClassifiedByShortSide() {
        XCTAssertEqual(item(width: 2160, height: 3840, duration: 1).resolutionLabel, "4K")
    }

    func testDurationLabels() {
        XCTAssertEqual(item(width: 1, height: 1, duration: 65).durationLabel, "1:05")
        XCTAssertEqual(item(width: 1, height: 1, duration: 9).durationLabel, "0:09")
        XCTAssertEqual(item(width: 1, height: 1, duration: .infinity).durationLabel, "—")
    }
}
