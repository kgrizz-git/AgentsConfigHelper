import Cocoa
import Darwin
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      TestRootFileChannel.register(with: controller)
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

enum TestRootFileOperationError: LocalizedError {
  case invalidPath(String)
  case unsupportedText
  case posix(operation: String, code: Int32)

  var errorDescription: String? {
    switch self {
    case .invalidPath(let message):
      return message
    case .unsupportedText:
      return "The file does not contain valid UTF-8 text."
    case .posix(let operation, let code):
      return "\(operation) failed: \(String(cString: strerror(code))) (errno \(code))."
    }
  }
}

/// Performs test-root file operations through descriptor-relative POSIX calls.
///
/// This is deliberately not used by normal app I/O. The opt-in macOS
/// `--test-root` mode calls it after validating a marked, non-symlink root.
final class TestRootFileOperations {
  // Keep the opened root descriptor: a later pathname swap cannot redirect an
  // operation outside the root originally verified with O_NOFOLLOW.
  private var rootDescriptors = [String: Int32]()

  deinit {
    for descriptor in rootDescriptors.values {
      _ = close(descriptor)
    }
  }

  func fileExists(rootPath: String, relativePath: String) throws -> Bool {
    let components = try pathComponents(relativePath)
    return try withRootDescriptor(rootPath) { rootDescriptor in
      do {
        return try withParentDescriptor(
          rootDescriptor: rootDescriptor,
          components: components,
          createParents: false
        ) { parentDescriptor, leaf in
          let descriptor = openat(
            parentDescriptor,
            leaf,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC
          )
          if descriptor >= 0 {
            defer { _ = close(descriptor) }
            return try isRegularFileDescriptor(descriptor)
          }
          if errno == ENOENT {
            return false
          }
          throw TestRootFileOperationError.posix(
            operation: "openat",
            code: errno
          )
        }
      } catch TestRootFileOperationError.posix(_, let code) where code == ENOENT {
        // A missing intermediate directory means the queried file does not exist.
          return false
      }
    }
  }

  func directoryExists(rootPath: String, relativePath: String) throws -> Bool {
    let components = try pathComponents(relativePath)
    return try withRootDescriptor(rootPath) { rootDescriptor in
      do {
        return try withDirectoryDescriptor(
          rootDescriptor: rootDescriptor,
          components: components
        ) { _ in true }
      } catch TestRootFileOperationError.posix(_, let code) where code == ENOENT {
        return false
      }
    }
  }

  func readFile(rootPath: String, relativePath: String) throws -> Data {
    let components = try pathComponents(relativePath)
    return try withRootDescriptor(rootPath) { rootDescriptor in
      try withParentDescriptor(
        rootDescriptor: rootDescriptor,
        components: components,
        createParents: false
      ) { parentDescriptor, leaf in
        let descriptor = openat(
          parentDescriptor,
          leaf,
          O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
          throw TestRootFileOperationError.posix(
            operation: "openat",
            code: errno
          )
        }
        defer { _ = close(descriptor) }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
          let bytesRead = buffer.withUnsafeMutableBytes { buffer in
            Darwin.read(descriptor, buffer.baseAddress, buffer.count)
          }
          if bytesRead == 0 {
            return data
          }
          if bytesRead < 0 {
            if errno == EINTR {
              continue
            }
            throw TestRootFileOperationError.posix(
              operation: "read",
              code: errno
            )
          }
          data.append(contentsOf: buffer.prefix(Int(bytesRead)))
        }
      }
    }
  }

  func listFiles(rootPath: String, relativePath: String) throws -> [String] {
    let components = try pathComponents(relativePath)
    return try withRootDescriptor(rootPath) { rootDescriptor in
      try withDirectoryDescriptor(
        rootDescriptor: rootDescriptor,
        components: components
      ) { directoryDescriptor in
        let listingDescriptor = dup(directoryDescriptor)
        guard listingDescriptor >= 0, let directory = fdopendir(listingDescriptor) else {
          if listingDescriptor >= 0 {
            _ = close(listingDescriptor)
          }
          throw TestRootFileOperationError.posix(operation: "fdopendir", code: errno)
        }
        defer { _ = closedir(directory) }

        var names = [String]()
        while let entry = readdir(directory) {
          let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 0) {
              String(cString: $0)
            }
          }
          if name != "." && name != ".." {
            if try isRegularFile(name, in: directoryDescriptor) {
              names.append(name)
            }
          }
        }
        return names
      }
    }
  }

  func writeFile(rootPath: String, relativePath: String, data: Data) throws {
    let components = try pathComponents(relativePath)
    try withRootDescriptor(rootPath) { rootDescriptor in
      try withParentDescriptor(
        rootDescriptor: rootDescriptor,
        components: components,
        createParents: true
      ) { parentDescriptor, leaf in
        let temporaryName = ".agents-config-helper-\(UUID().uuidString).tmp"
        let descriptor = openat(
          parentDescriptor,
          temporaryName,
          O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
          mode_t(S_IRUSR | S_IWUSR)
        )
        guard descriptor >= 0 else {
          throw TestRootFileOperationError.posix(
            operation: "openat temporary file",
            code: errno
          )
        }

        var shouldRemoveTemporary = true
        defer {
          _ = close(descriptor)
          if shouldRemoveTemporary {
            _ = unlinkat(parentDescriptor, temporaryName, 0)
          }
        }

        try writeAll(data, to: descriptor)
        guard fsync(descriptor) == 0 else {
          throw TestRootFileOperationError.posix(operation: "fsync", code: errno)
        }
        guard renameat(parentDescriptor, temporaryName, parentDescriptor, leaf) == 0 else {
          throw TestRootFileOperationError.posix(operation: "renameat", code: errno)
        }
        shouldRemoveTemporary = false
        guard fsync(parentDescriptor) == 0 else {
          throw TestRootFileOperationError.posix(
            operation: "fsync parent directory",
            code: errno
          )
        }
      }
    }
  }

  func copyFile(
    rootPath: String,
    sourceRelativePath: String,
    destinationRelativePath: String
  ) throws {
    let source = try readFile(rootPath: rootPath, relativePath: sourceRelativePath)
    try writeFile(
      rootPath: rootPath,
      relativePath: destinationRelativePath,
      data: source
    )
  }

  func deleteFile(rootPath: String, relativePath: String) throws {
    let components = try pathComponents(relativePath)
    try withRootDescriptor(rootPath) { rootDescriptor in
      try withParentDescriptor(
        rootDescriptor: rootDescriptor,
        components: components,
        createParents: false
      ) { parentDescriptor, leaf in
        guard unlinkat(parentDescriptor, leaf, 0) == 0 else {
          throw TestRootFileOperationError.posix(operation: "unlinkat", code: errno)
        }
      }
    }
  }

  private func withRootDescriptor<T>(
    _ rootPath: String,
    body: (Int32) throws -> T
  ) throws -> T {
    if let descriptor = rootDescriptors[rootPath] {
      return try body(descriptor)
    }
    guard rootPath.hasPrefix("/") else {
      throw TestRootFileOperationError.invalidPath("Test root must be absolute.")
    }

    let descriptor = open(
      rootPath,
      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
    )
    guard descriptor >= 0 else {
      throw TestRootFileOperationError.posix(operation: "open test root", code: errno)
    }
    rootDescriptors[rootPath] = descriptor
    return try body(descriptor)
  }

  private func pathComponents(_ relativePath: String) throws -> [String] {
    guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
      throw TestRootFileOperationError.invalidPath(
        "Path must be a non-empty relative path."
      )
    }

    let components = relativePath.split(
      separator: "/",
      omittingEmptySubsequences: false
    ).map(String.init)
    guard components.allSatisfy({
      !$0.isEmpty && $0 != "." && $0 != ".."
    }) else {
      throw TestRootFileOperationError.invalidPath(
        "Path must not contain empty, '.' or '..' components."
      )
    }
    return components
  }

  private func withParentDescriptor<T>(
    rootDescriptor: Int32,
    components: [String],
    createParents: Bool,
    body: (Int32, String) throws -> T
  ) throws -> T {
    var currentDescriptor = rootDescriptor
    var ownsCurrentDescriptor = false
    defer {
      if ownsCurrentDescriptor {
        _ = close(currentDescriptor)
      }
    }

    for component in components.dropLast() {
      if createParents, mkdirat(currentDescriptor, component, mode_t(S_IRWXU)) != 0,
         errno != EEXIST {
        throw TestRootFileOperationError.posix(operation: "mkdirat", code: errno)
      }

      let nextDescriptor = openat(
        currentDescriptor,
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      guard nextDescriptor >= 0 else {
        throw TestRootFileOperationError.posix(operation: "openat directory", code: errno)
      }
      if ownsCurrentDescriptor {
        _ = close(currentDescriptor)
      }
      currentDescriptor = nextDescriptor
      ownsCurrentDescriptor = true
    }

    guard let leaf = components.last else {
      throw TestRootFileOperationError.invalidPath("Path must name a file.")
    }
    return try body(currentDescriptor, leaf)
  }

  private func withDirectoryDescriptor<T>(
    rootDescriptor: Int32,
    components: [String],
    body: (Int32) throws -> T
  ) throws -> T {
    var currentDescriptor = rootDescriptor
    var ownsCurrentDescriptor = false
    defer {
      if ownsCurrentDescriptor {
        _ = close(currentDescriptor)
      }
    }

    for component in components {
      let nextDescriptor = openat(
        currentDescriptor,
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      guard nextDescriptor >= 0 else {
        throw TestRootFileOperationError.posix(operation: "openat directory", code: errno)
      }
      if ownsCurrentDescriptor {
        _ = close(currentDescriptor)
      }
      currentDescriptor = nextDescriptor
      ownsCurrentDescriptor = true
    }
    return try body(currentDescriptor)
  }

  private func writeAll(_ data: Data, to descriptor: Int32) throws {
    var offset = 0
    try data.withUnsafeBytes { buffer in
      while offset < data.count {
        let bytesWritten = Darwin.write(
          descriptor,
          buffer.baseAddress!.advanced(by: offset),
          data.count - offset
        )
        if bytesWritten < 0 {
          if errno == EINTR {
            continue
          }
          throw TestRootFileOperationError.posix(operation: "write", code: errno)
        }
        offset += Int(bytesWritten)
      }
    }
  }

  private func isRegularFile(_ name: String, in directoryDescriptor: Int32) throws -> Bool {
    var status = stat()
    guard fstatat(directoryDescriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
      throw TestRootFileOperationError.posix(operation: "fstatat", code: errno)
    }
    return (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
  }

  private func isRegularFileDescriptor(_ descriptor: Int32) throws -> Bool {
    var status = stat()
    guard fstat(descriptor, &status) == 0 else {
      throw TestRootFileOperationError.posix(operation: "fstat", code: errno)
    }
    return (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
  }
}

private enum TestRootFileChannel {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "agents_config_helper/test_root_file_operations",
      binaryMessenger: controller.engine.binaryMessenger
    )
    let operations = TestRootFileOperations()

    channel.setMethodCallHandler { call, result in
      do {
        guard let arguments = call.arguments as? [String: Any],
              let rootPath = arguments["rootPath"] as? String else {
          throw TestRootFileOperationError.invalidPath("Missing test-root arguments.")
        }

        switch call.method {
        case "fileExists":
          let relativePath = try requiredRelativePath(arguments)
          result(try operations.fileExists(rootPath: rootPath, relativePath: relativePath))
        case "directoryExists":
          let relativePath = try requiredRelativePath(arguments)
          result(try operations.directoryExists(rootPath: rootPath, relativePath: relativePath))
        case "readText":
          let relativePath = try requiredRelativePath(arguments)
          let data = try operations.readFile(rootPath: rootPath, relativePath: relativePath)
          guard let text = String(data: data, encoding: .utf8) else {
            throw TestRootFileOperationError.unsupportedText
          }
          result(text)
        case "readBytes":
          let relativePath = try requiredRelativePath(arguments)
          let data = try operations.readFile(rootPath: rootPath, relativePath: relativePath)
          result(FlutterStandardTypedData(bytes: data))
        case "writeText":
          let relativePath = try requiredRelativePath(arguments)
          guard let text = arguments["text"] as? String else {
            throw TestRootFileOperationError.invalidPath("Missing text content.")
          }
          try operations.writeFile(
            rootPath: rootPath,
            relativePath: relativePath,
            data: Data(text.utf8)
          )
          result(nil)
        case "writeBytes":
          let relativePath = try requiredRelativePath(arguments)
          guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else {
            throw TestRootFileOperationError.invalidPath("Missing byte content.")
          }
          try operations.writeFile(
            rootPath: rootPath,
            relativePath: relativePath,
            data: bytes.data
          )
          result(nil)
        case "copyFile":
          let sourceRelativePath = try requiredRelativePath(arguments, key: "sourceRelativePath")
          let destinationRelativePath = try requiredRelativePath(
            arguments,
            key: "destinationRelativePath"
          )
          try operations.copyFile(
            rootPath: rootPath,
            sourceRelativePath: sourceRelativePath,
            destinationRelativePath: destinationRelativePath
          )
          result(nil)
        case "listFiles":
          let relativePath = try requiredRelativePath(arguments)
          result(try operations.listFiles(rootPath: rootPath, relativePath: relativePath))
        case "deleteFile":
          let relativePath = try requiredRelativePath(arguments)
          try operations.deleteFile(rootPath: rootPath, relativePath: relativePath)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(
          FlutterError(
            code: "test_root_file_operation_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private static func requiredRelativePath(
    _ arguments: [String: Any],
    key: String = "relativePath"
  ) throws -> String {
    guard let relativePath = arguments[key] as? String else {
      throw TestRootFileOperationError.invalidPath("Missing \(key).")
    }
    return relativePath
  }
}
