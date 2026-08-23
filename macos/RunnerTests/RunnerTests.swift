import Cocoa
import FlutterMacOS
import XCTest

@testable import agents_config_helper

class RunnerTests: XCTestCase {
  private var root: URL!
  private var operations: TestRootFileOperations!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("agents-config-helper-test-root-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700]
    )
    try Data("agents-config-helper staging root v1".utf8).write(
      to: root.appendingPathComponent(".agents-config-helper-test-root")
    )
    operations = TestRootFileOperations()
    try operations.pinRoot(rootPath: root.path)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  func testWritesReadsAndCopiesInsideRoot() throws {
    try operations.writeFile(
      rootPath: root.path,
      relativePath: ".claude/settings.json",
      data: Data("{\"endpoint\": \"https://example.invalid\"}".utf8)
    )

    let source = try operations.readFile(
      rootPath: root.path,
      relativePath: ".claude/settings.json"
    )
    XCTAssertEqual(String(data: source, encoding: .utf8), "{\"endpoint\": \"https://example.invalid\"}")
    XCTAssertTrue(
      try operations.fileExists(
        rootPath: root.path,
        relativePath: ".claude/settings.json"
      )
    )

    try operations.copyFile(
      rootPath: root.path,
      sourceRelativePath: ".claude/settings.json",
      destinationRelativePath: "application-support/backups/settings.json.bak"
    )
    XCTAssertEqual(
      try String(
        data: operations.readFile(
          rootPath: root.path,
          relativePath: "application-support/backups/settings.json.bak"
        ),
        encoding: .utf8
      ),
      "{\"endpoint\": \"https://example.invalid\"}"
    )
    XCTAssertTrue(
      try operations.directoryExists(
        rootPath: root.path,
        relativePath: "application-support/backups"
      )
    )
    XCTAssertFalse(
      try operations.fileExists(
        rootPath: root.path,
        relativePath: "application-support/backups"
      )
    )
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("application-support/backups/ignored.bak"),
      withDestinationURL: root.appendingPathComponent(".claude/settings.json")
    )
    XCTAssertEqual(
      try operations.listFiles(
        rootPath: root.path,
        relativePath: "application-support/backups"
      ),
      ["settings.json.bak"]
    )
    try operations.deleteFile(
      rootPath: root.path,
      relativePath: "application-support/backups/settings.json.bak"
    )
    XCTAssertFalse(
      try operations.fileExists(
        rootPath: root.path,
        relativePath: "application-support/backups/settings.json.bak"
      )
    )
  }

  func testRejectsSymlinkedRoot() throws {
    let linkedRoot = root.deletingLastPathComponent().appendingPathComponent("linked-root")
    try FileManager.default.createSymbolicLink(
      at: linkedRoot,
      withDestinationURL: root
    )
    defer { try? FileManager.default.removeItem(at: linkedRoot) }

    XCTAssertThrowsError(
      try TestRootFileOperations().pinRoot(rootPath: linkedRoot.path)
    )
  }

  func testRejectsAnUnmarkedRoot() throws {
    let unmarkedRoot = root.deletingLastPathComponent().appendingPathComponent(
      "unmarked-root-\(UUID().uuidString)"
    )
    try FileManager.default.createDirectory(
      at: unmarkedRoot,
      withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: unmarkedRoot) }

    XCTAssertThrowsError(
      try TestRootFileOperations().pinRoot(rootPath: unmarkedRoot.path)
    )
  }

  func testRejectsOperationsBeforeRootIsPinned() throws {
    XCTAssertThrowsError(
      try TestRootFileOperations().writeFile(
        rootPath: root.path,
        relativePath: "settings.json",
        data: Data("{}".utf8)
      )
    )
  }

  func testReportsFalseWhenAnIntermediateDirectoryDoesNotExist() throws {
    XCTAssertFalse(
      try operations.fileExists(
        rootPath: root.path,
        relativePath: ".missing/nested/settings.json"
      )
    )
    XCTAssertFalse(
      try operations.directoryExists(
        rootPath: root.path,
        relativePath: ".missing/nested"
      )
    )
  }

  func testKeepsUsingThePinnedRootAfterAPathSwap() throws {
    let movedRoot = root.deletingLastPathComponent().appendingPathComponent("moved-root")
    let outside = root.deletingLastPathComponent().appendingPathComponent("swap-outside")
    try FileManager.default.createDirectory(
      at: outside,
      withIntermediateDirectories: false
    )
    try FileManager.default.moveItem(at: root, to: movedRoot)
    try FileManager.default.createSymbolicLink(at: root, withDestinationURL: outside)
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: movedRoot)
      try? FileManager.default.removeItem(at: outside)
    }

    try operations.writeFile(
      rootPath: root.path,
      relativePath: "after-swap.json",
      data: Data("after".utf8)
    )

    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: movedRoot.appendingPathComponent("after-swap.json").path
      )
    )
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: outside.appendingPathComponent("after-swap.json").path
      )
    )
  }

  func testRejectsSymlinkedParentWithoutWritingOutsideRoot() throws {
    let outside = root.deletingLastPathComponent().appendingPathComponent("outside-parent")
    try FileManager.default.createDirectory(
      at: outside,
      withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: outside) }

    let linkedParent = root.appendingPathComponent("linked-parent")
    try FileManager.default.createSymbolicLink(
      at: linkedParent,
      withDestinationURL: outside
    )

    XCTAssertThrowsError(
      try operations.writeFile(
        rootPath: root.path,
        relativePath: "linked-parent/settings.json",
        data: Data("{}".utf8)
      )
    )
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: outside.appendingPathComponent("settings.json").path
      )
    )
  }

  func testReplacesTargetSymlinkWithoutFollowingIt() throws {
    let outside = root.deletingLastPathComponent().appendingPathComponent("outside-target.json")
    try Data("outside".utf8).write(to: outside)
    defer { try? FileManager.default.removeItem(at: outside) }

    let target = root.appendingPathComponent("settings.json")
    try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)

    try operations.writeFile(
      rootPath: root.path,
      relativePath: "settings.json",
      data: Data("inside".utf8)
    )

    XCTAssertEqual(try String(contentsOf: outside), "outside")
    XCTAssertEqual(try String(contentsOf: target), "inside")
  }

  func testRejectsTraversalAndSymlinkedCopySource() throws {
    XCTAssertThrowsError(
      try operations.writeFile(
        rootPath: root.path,
        relativePath: "../outside.json",
        data: Data("{}".utf8)
      )
    )

    let outside = root.deletingLastPathComponent().appendingPathComponent("outside-source.json")
    try Data("outside".utf8).write(to: outside)
    defer { try? FileManager.default.removeItem(at: outside) }
    let linkedSource = root.appendingPathComponent("linked-source.json")
    try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: outside)

    XCTAssertThrowsError(
      try operations.copyFile(
        rootPath: root.path,
        sourceRelativePath: "linked-source.json",
        destinationRelativePath: "copy.json"
      )
    )
    XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("copy.json").path))
  }
}
