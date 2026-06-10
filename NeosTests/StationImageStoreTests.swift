import XCTest
@testable import Neos

final class StationImageStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clean both legacy UserDefaults and JSON file
        UserDefaults.standard.removeObject(forKey: "customStationImages")
        // Remove the JSON file to start fresh
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let file = appSupport.appendingPathComponent("Neos/custom-artwork.json")
        try? FileManager.default.removeItem(at: file)
        StationImageStore.resetCache()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "customStationImages")
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let file = appSupport.appendingPathComponent("Neos/custom-artwork.json")
        try? FileManager.default.removeItem(at: file)
        StationImageStore.resetCache()
        super.tearDown()
    }

    func testEmptyByDefault() {
        XCTAssertTrue(StationImageStore.all().isEmpty)
        XCTAssertNil(StationImageStore.imageURL(forMID: "s/12345"))
        XCTAssertFalse(StationImageStore.hasCustomImage(forMID: "s/12345"))
    }

    func testSetAndRetrieveImage() {
        StationImageStore.setImageURL("https://example.com/logo.png", forMID: "s/100")

        XCTAssertEqual(StationImageStore.imageURL(forMID: "s/100"), "https://example.com/logo.png")
        XCTAssertTrue(StationImageStore.hasCustomImage(forMID: "s/100"))
    }

    func testRemoveImage() {
        StationImageStore.setImageURL("https://example.com/logo.png", forMID: "s/100")
        StationImageStore.removeImage(forMID: "s/100")

        XCTAssertNil(StationImageStore.imageURL(forMID: "s/100"))
        XCTAssertFalse(StationImageStore.hasCustomImage(forMID: "s/100"))
    }

    func testResolvedImageURLPrefersCustom() {
        StationImageStore.setImageURL("https://custom.com/art.png", forMID: "s/200")

        let resolved = StationImageStore.resolvedImageURL(
            forMID: "s/200",
            originalURL: "https://heos.com/default.png"
        )
        XCTAssertEqual(resolved, "https://custom.com/art.png")
    }

    func testResolvedImageURLFallsBackToOriginal() {
        let resolved = StationImageStore.resolvedImageURL(
            forMID: "s/300",
            originalURL: "https://heos.com/default.png"
        )
        XCTAssertEqual(resolved, "https://heos.com/default.png")
    }

    func testResolvedImageURLNilMID() {
        let resolved = StationImageStore.resolvedImageURL(
            forMID: nil,
            originalURL: "https://heos.com/default.png"
        )
        XCTAssertEqual(resolved, "https://heos.com/default.png")
    }

    func testResolvedImageURLBothNil() {
        let resolved = StationImageStore.resolvedImageURL(forMID: nil, originalURL: nil)
        XCTAssertNil(resolved)
    }

    func testMultipleStations() {
        StationImageStore.setImageURL("https://a.com/1.png", forMID: "s/1")
        StationImageStore.setImageURL("https://b.com/2.png", forMID: "s/2")

        XCTAssertEqual(StationImageStore.all().count, 2)
        XCTAssertEqual(StationImageStore.imageURL(forMID: "s/1"), "https://a.com/1.png")
        XCTAssertEqual(StationImageStore.imageURL(forMID: "s/2"), "https://b.com/2.png")
    }

    func testOverwriteExistingImage() {
        StationImageStore.setImageURL("https://old.com/art.png", forMID: "s/1")
        StationImageStore.setImageURL("https://new.com/art.png", forMID: "s/1")

        XCTAssertEqual(StationImageStore.imageURL(forMID: "s/1"), "https://new.com/art.png")
        XCTAssertEqual(StationImageStore.all().count, 1)
    }

    func testRemoveNonexistentIsNoOp() {
        StationImageStore.setImageURL("https://a.com/1.png", forMID: "s/1")
        StationImageStore.removeImage(forMID: "s/999")

        XCTAssertEqual(StationImageStore.all().count, 1)
    }

    func testMigratesFromUserDefaults() {
        // Simulate legacy data in UserDefaults
        UserDefaults.standard.set(
            ["s/legacy": "https://old.com/legacy.png"],
            forKey: "customStationImages"
        )

        // all() should migrate and return legacy data
        let map = StationImageStore.all()
        XCTAssertEqual(map["s/legacy"], "https://old.com/legacy.png")

        // UserDefaults should be cleaned up
        XCTAssertNil(UserDefaults.standard.dictionary(forKey: "customStationImages"))

        // JSON file should persist after migration
        XCTAssertEqual(StationImageStore.imageURL(forMID: "s/legacy"), "https://old.com/legacy.png")
    }

    func testPersistsToJSONFile() {
        StationImageStore.setImageURL("https://example.com/art.png", forMID: "s/json")

        // Verify file exists
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let file = appSupport.appendingPathComponent("Neos/custom-artwork.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        // Verify content is valid JSON
        let data = try! Data(contentsOf: file)
        let map = try! JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(map["s/json"], "https://example.com/art.png")
    }
}
