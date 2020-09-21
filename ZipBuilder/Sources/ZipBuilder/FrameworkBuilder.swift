/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/// Different architectures to build frameworks for.
private enum Architecture: String, CaseIterable {
  /// The target platform that the framework is built for.
  enum TargetPlatform: String, CaseIterable {
    /// iOS and iPadOS devices.
    case device = "iphoneos"
    /// iOS and iPadOS simulators.
    case simulator = "iphonesimulator"
    /// iPad Apps on macOS.
    case catalyst = "uikitformac"

    /// Extra C flags that should be included as part of the build process for each target platform.
    func otherCFlags() -> [String] {
      switch self {
      case .device:
        // For device, we want to enable bitcode.
        return ["-fembed-bitcode"]
      default:
        return []
      }
    }

    /// Arguments that should be included as part of the build process for each target platform.
    func extraArguments() -> [String] {
      let base = ["-sdk", rawValue]
      switch self {
      case .catalyst:
        return ["SKIP_INSTALL=NO",
                "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
                "SUPPORTS_UIKITFORMAC=YES"]
      case .simulator:
        // No extra arguments are required for simulator or device builds.
        return base
      }
    }
  }

  case arm64
  case armv7
  case i386
  /// iOS Simulator.
  case x86_64
  /// iPad Apps on macOS.
  case x86_64Catalyst

  /// The actual parameter for passing the architecture to `xcodebuild`.
  var parameter: String {
    switch self {
    case .x86_64Catalyst: return "x86_64"
    default: return rawValue
    }
  }

  /// The platform associated with the architecture.
  var platform: TargetPlatform {
    switch self {
    case .arm64, .armv7: return .device
    case .i386, .x86_64: return .simulator
    case .x86_64Catalyst: return .catalyst
    }
  }
}

/// A structure to build a .framework in a given project directory.
struct FrameworkBuilder {
  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// A flag to indicate this build is for carthage. This is primarily used for CoreDiagnostics.
  private let carthageBuild: Bool

  /// The Pods directory for building the framework.
  private var podsDir: URL {
    return projectDir.appendingPathComponent("Pods", isDirectory: true)
  }

  /// Default initializer.
  init(projectDir: URL, carthageBuild: Bool = false) {
    self.projectDir = projectDir
    self.carthageBuild = carthageBuild
  }

  // MARK: - Public Functions

  /// Build a fat library framework file for a given framework name.
  ///
  /// - Parameters:
  ///   - framework: The name of the Framework being built.
  ///   - version: String representation of the version.
  ///   - cacheKey: The key used for caching this framework build. If nil, the framework name will
  ///               be used.
  ///   - cacheEnabled: Flag for enabling the cache. Defaults to false.
  /// - Parameter logsOutputDir: The path to the directory to place build logs.
  /// - Returns: A URL to the framework that was built (or pulled from the cache).
  public func buildFramework(withName podName: String,
                             version: String,
                             cacheKey: String?,
                             cacheEnabled: Bool = false,
                             logsOutputDir: URL? = nil) -> URL {
    print("Building \(podName)")

//  Cache is temporarily disabled due to pod cache list issues.
    // Get the CocoaPods cache to see if we can pull from any frameworks already built.
//    let podsCache = CocoaPodUtils.listPodCache(inDir: projectDir)
//
//    guard let cachedVersions = podsCache[podName] else {
//      fatalError("Cannot find a pod cache for framework \(podName).")
//    }
//
//    guard let podInfo = cachedVersions[version] else {
//      fatalError("""
//      Cannot find a pod cache for framework \(podName) at version \(version).
//      Something could be wrong with your CocoaPods cache - try running the following:
//
//      pod cache clean '\(podName)' --all
//      """)
//    }
//
//    // TODO: Figure out if we need the MD5 at all.
    let md5 = podName
//    let md5 = Shell.calculateMD5(for: podInfo.installedLocation)

    // Get (or create) the cache directory for storing built frameworks.
    let fileManager = FileManager.default
    var cachedFrameworkRoot: URL
    do {
      let cacheDir = try fileManager.firebaseCacheDirectory()
      cachedFrameworkRoot = cacheDir.appendingPathComponents([podName, version, md5])
      if let cacheKey = cacheKey {
        cachedFrameworkRoot.appendPathComponent(cacheKey)
      }
    } catch {
      fatalError("Could not create caches directory for building frameworks: \(error)")
    }

    // Build the full cached framework path.
    let cachedFrameworkDir = cachedFrameworkRoot.appendingPathComponent("\(podName).framework")
    let cachedFrameworkExists = fileManager.directoryExists(at: cachedFrameworkDir)
    if cachedFrameworkExists, cacheEnabled {
      print("Framework \(podName) version \(version) has already been built and cached at " +
        "\(cachedFrameworkDir)")
      return cachedFrameworkDir
    } else {
      let frameworkDir = compileFrameworkAndResources(withName: podName)
      do {
        // Remove the previously cached framework, if it exists, otherwise the `moveItem` call will
        // fail.
        if cachedFrameworkExists {
          try fileManager.removeItem(at: cachedFrameworkDir)
        } else if !fileManager.directoryExists(at: cachedFrameworkRoot) {
          // If the root directory doesn't exist, create it so the `moveItem` will succeed.
          try fileManager.createDirectory(at: cachedFrameworkRoot,
                                          withIntermediateDirectories: true)
        }

        // Move the newly built framework to the cache directory.
        try fileManager.moveItem(at: frameworkDir, to: cachedFrameworkDir)
        return cachedFrameworkDir
      } catch {
        fatalError("Could not move built frameworks into the cached frameworks directory: \(error)")
      }
    }
  }

  // MARK: - Private Helpers

  /// This runs a command and immediately returns a Shell result.
  /// NOTE: This exists in conjunction with the `Shell.execute...` due to issues with different
  ///       `.bash_profile` environment variables. This should be consolidated in the future.
  private func syncExec(command: String, args: [String] = [], captureOutput: Bool = false) -> Shell.Result {
    let task = Process()
    task.launchPath = command
    task.arguments = args

    // If we want to output to the console, create a readabilityHandler and save each line along the
    // way. Otherwise, we can just read the pipe at the end. By disabling outputToConsole, some
    // commands (such as any xcodebuild) can run much, much faster.
    var output: [String] = []
    if captureOutput {
      let pipe = Pipe()
      task.standardOutput = pipe
      let outHandle = pipe.fileHandleForReading

      outHandle.readabilityHandler = { pipe in
        // This will be run any time data is sent to the pipe. We want to print it and store it for
        // later. Ignore any non-valid Strings.
        guard let line = String(data: pipe.availableData, encoding: .utf8) else {
          print("Could not get data from pipe for command \(command): \(pipe.availableData)")
          return
        }
        output.append(line)
      }
      // Also set the termination handler on the task in order to stop the readabilityHandler from
      // parsing any more data from the task.
      task.terminationHandler = { t in
        guard let stdOut = t.standardOutput as? Pipe else { return }

        stdOut.fileHandleForReading.readabilityHandler = nil
      }
    } else {
      // No capturing output, just mark it as complete.
      output = ["The task completed"]
    }

    task.launch()
    task.waitUntilExit()

    let fullOutput = output.joined(separator: "\n")

    // Normally we'd use a pipe to retrieve the output, but for whatever reason it slows things down
    // tremendously for xcodebuild.
    guard task.terminationStatus == 0 else {
      return .error(code: task.terminationStatus, output: fullOutput)
    }

    return .success(output: fullOutput)
  }

  /// Uses `xcodebuild` to build a framework for a specific architecture slice.
  ///
  /// - Parameters:
  ///   - framework: Name of the framework being built.
  ///   - arch: Architecture slice to build.
  ///   - buildDir: Location where the project should be built.
  ///   - logRoot: Root directory where all logs should be written.
  /// - Returns: A URL to the thin library that was built.
  private func buildThin(framework: String,
                         arch: Architecture,
                         buildDir: URL,
                         logRoot: URL) -> URL {
    let workspacePath = projectDir.appendingPathComponent("FrameworkMaker.xcworkspace").path
    let distributionFlag = carthageBuild ? "-DFIREBASE_BUILD_CARTHAGE" : "-DFIREBASE_BUILD_ZIP_FILE"
    let platform = arch.platform
    let platformSpecificFlags = platform.otherCFlags().joined(separator: " ")
    let cFlags = "OTHER_CFLAGS=$(value) \(distributionFlag) \(platformSpecificFlags)"
    let standardOptions = ["build",
                           "-configuration", "release",
                           "-workspace", workspacePath,
                           "-scheme", framework,
                           "GCC_GENERATE_DEBUGGING_SYMBOLS=No",
                           "ARCHS=\(arch.parameter)",
                           "BUILD_DIR=\(buildDir.path)",
                           "-sdk", platform.rawValue,
                           cFlags]
    let args = standardOptions + platform.extraArguments()
    print("""
    Compiling \(framework) for \(arch.parameter), \(platform.rawValue) with command:
    /usr/bin/xcodebuild \(args.joined(separator: " "))
    """)

    // Regardless if it succeeds or not, we want to write the log to file in case we need to inspect
    // things further.
    let logFileName = "\(framework)-\(arch.rawValue)-\(platform.rawValue).txt"
    let logFile = logRoot.appendingPathComponent(logFileName)

    let result = syncExec(command: "/usr/bin/xcodebuild", args: args, captureOutput: true)
    switch result {
    case let .error(code, output):
      // Write output to disk and print the location of it. Force unwrapping here since it's going
      // to crash anyways, and at this point the root log directory exists, we know it's UTF8, so it
      // should pass every time. Revisit if that's not the case.
      try! output.write(to: logFile, atomically: true, encoding: .utf8)
      fatalError("Error building \(framework) for \(arch.rawValue). Code: \(code). See the build " +
        "log at \(logFile)")

    case let .success(output):
      // Try to write the output to the log file but if it fails it's not a huge deal since it was
      // a successful build.
      try? output.write(to: logFile, atomically: true, encoding: .utf8)
      print("""
      Successfully built \(framework) for \(arch.rawValue). Build log can be found at \(logFile)
      """)

      // Use the Xcode-generated path to return the path to the compiled library.
      let libPath = buildDir.appendingPathComponents(["Release-\(platform.rawValue)",
                                                      framework,
                                                      "lib\(framework).a"])
      return libPath
    }
  }

  // Extract the framework and library dependencies for a framework from
  // Pods/Target Support Files/{framework}/{framework}.xcconfig.
  private func getModuleDependencies(forFramework framework: String) ->
    (frameworks: [String], libraries: [String]) {
    let xcconfigFile = podsDir.appendingPathComponents(["Target Support Files",
                                                        framework,
                                                        "\(framework).xcconfig"])
    do {
      let text = try String(contentsOf: xcconfigFile)
      let lines = text.components(separatedBy: .newlines)
      for line in lines {
        if line.hasPrefix("OTHER_LDFLAGS =") {
          var dependencyFrameworks: [String] = []
          var dependencyLibraries: [String] = []
          let tokens = line.components(separatedBy: " ")
          var addNext = false
          for token in tokens {
            if addNext {
              dependencyFrameworks.append(token)
              addNext = false
            } else if token == "-framework" {
              addNext = true
            } else if token.hasPrefix("-l") {
              let index = token.index(token.startIndex, offsetBy: 2)
              dependencyLibraries.append(String(token[index...]))
            }
          }

          return (dependencyFrameworks, dependencyLibraries)
        }
      }
    } catch {
      fatalError("Failed to open \(xcconfigFile): \(error)")
    }
    return ([], [])
  }

  private func makeModuleMap(framework: String, dir: URL) {
    let dependencies = getModuleDependencies(forFramework: framework)
    let moduleDir = dir.appendingPathComponent("Modules")
    do {
      try FileManager.default.createDirectory(at: moduleDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create Modules directory for framework: \(framework). \(error)")
    }

    // Check if there's an explicit umbrella header or not for this framework. If so, use it as the
    // umbrella header. If not, use the `Headers` directory as an umbrella directory for all
    // headers.
    let headersDir = dir.appendingPathComponent("Headers")
    let allHeaders: [String]
    let umbrellaStatement: String
    do {
      allHeaders = try FileManager.default.contentsOfDirectory(atPath: headersDir.path)
      print("All headers: \(allHeaders)")
      if allHeaders.contains("\(framework).h") {
        // Use the explicit umbrella header.
        umbrellaStatement = "umbrella header \"\(framework).h\""
      } else {
        // Use the "Headers" folder as the umbrella folder for all headers.
        umbrellaStatement = "umbrella \"Headers\""
      }
    } catch {
      fatalError("Could not read Headers directory for \(framework): \(error)")
    }

    let modulemap = moduleDir.appendingPathComponent("module.modulemap")
    // The base of the module map. The empty line at the end is intentional, do not remove it.
    var content = """
    framework module \(framework) {
    \(umbrellaStatement)
    export *
    module * { export * }

    """
    for framework in dependencies.frameworks {
      content += "  link framework " + framework + "\n"
    }
    for library in dependencies.libraries {
      content += "  link " + library + "\n"
    }
    content += "}\n"

    do {
      try content.write(to: modulemap, atomically: true, encoding: .utf8)
    } catch {
      fatalError("Could not write modulemap to disk for \(framework): \(error)")
    }
  }

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the lipo command to create a "fat" archive.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsOutputDir: The path to the directory to place build logs.
  /// - Returns: A path to the newly compiled framework (with any included Resources embedded).
  private func compileFrameworkAndResources(withName framework: String,
                                            logsOutputDir: URL? = nil) -> URL {
    let fileManager = FileManager.default
    let outputDir = fileManager.temporaryDirectory(withName: "frameworks_being_built")
    let logsDir = logsOutputDir ?? fileManager.temporaryDirectory(withName: "build_logs")
    do {
      // Remove the compiled frameworks directory, this isn't the cache we're using.
      if fileManager.directoryExists(at: outputDir) {
        try fileManager.removeItem(at: outputDir)
      }

      try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

      // Create our logs directory if it doesn't exist.
      if !fileManager.directoryExists(at: logsDir) {
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
      }
    } catch {
      fatalError("Failure creating temporary directory while building \(framework): \(error)")
    }

    // Build every architecture and save the locations in an array to be assembled.
    // TODO: Pass in supported architectures here, for those open source SDKs that don't support
    // individual architectures.
    var thinArchives = [Architecture: URL]()
    for arch in Architecture.allCases {
      let buildDir = projectDir.appendingPathComponent(arch.rawValue)
      let thinArchive = buildThin(framework: framework,
                                  arch: arch,
                                  buildDir: buildDir,
                                  logRoot: logsDir)
      thinArchives[arch] = thinArchive
    }

    // Create the framework directory in the filesystem for the thin archives to go.
    let frameworkDir = outputDir.appendingPathComponent("\(framework).framework")
    do {
      try fileManager.createDirectory(at: frameworkDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create framework directory while building framework \(framework). " +
        "\(error)")
    }

    // Verify Firebase headers include an explicit umbrella header for Firebase.h.
    let headersDir = podsDir.appendingPathComponents(["Headers", "Public", framework])
    if framework.hasPrefix("Firebase"), framework != "FirebaseCoreDiagnostics" {
      let frameworkHeader = headersDir.appendingPathComponent("\(framework).h")
      guard fileManager.fileExists(atPath: frameworkHeader.path) else {
        fatalError("Missing explicit umbrella header for \(framework).")
      }
    }

    // Copy the Headers over. Pass in the prefix to remove in order to generate the relative paths
    // for some frameworks that have nested folders in their public headers.
    let headersDestination = frameworkDir.appendingPathComponent("Headers")
    do {
      try recursivelyCopyHeaders(from: headersDir, to: headersDestination)
    } catch {
      fatalError("Could not copy headers from \(headersDir) to Headers directory in " +
        "\(headersDestination): \(error)")
    }

    // Move all the Resources into .bundle directories in the destination Resources dir. The
    // Resources live are contained within the folder structure:
    // `projectDir/arch/Release-platform/FrameworkName`
    let arch = Architecture.arm64
    let contentsDir = projectDir.appendingPathComponents([arch.rawValue,
                                                          "Release-\(arch.platform.rawValue)",
                                                          framework])
    let resourceDir = frameworkDir.appendingPathComponent("Resources")
    do {
      try ResourcesManager.moveAllBundles(inDirectory: contentsDir, to: resourceDir)
    } catch {
      fatalError("Could not move bundles into Resources directory while building \(framework): " +
        "\(error)")
    }

    makeModuleMap(framework: framework, dir: frameworkDir)

    let xcframework = packageXCFramework(withName: framework,
                                         fromFolder: frameworkDir,
                                         thinArchives: thinArchives)
//    let framework = packageFramework(withName: framework,
//                                     fromFolder: frameworkDir,
//                                     thinArchives: thinArchives)

    // Remove the temporary thin archives.
    for thinArchive in thinArchives.values {
      do {
        try fileManager.removeItem(at: thinArchive)
      } catch {
        // Just log a warning instead of failing, since this doesn't actually affect the build
        // itself. This should only be shown to help users clean up their disk afterwards.
        print("""
        WARNING: Failed to remove temporary thin archive at \(thinArchive.path). This should be
        removed from your system to save disk space. \(error). You should be able to remove the
        archive from Terminal with:
        rm \(thinArchive.path)
        """)
      }
    }

    //    return frameworkDir
    return xcframework
  }

  private func packageFramework(withName framework: String,
                                fromFolder: URL,
                                thinArchives: [Architecture: URL],
                                destination: URL) {
    // Build the fat archive using the `lipo` command. We need the full archive path and the list of
    // thin paths (as Strings, not URLs).
    let thinPaths = thinArchives.map { $0.value.path }

    // Store all fat archives in a temporary directory that includes all architectures included as
    // the parent folder.
    let fatArchivesDir: URL = {
      let allArchivesDir = FileManager.default.temporaryDirectory(withName: "fat_archives")
      let architectures = thinArchives.keys.map { $0.rawValue }.sorted()
      return allArchivesDir.appendingPathComponent(architectures.joined(separator: "_"))
    }()

    do {
      let fileManager = FileManager.default
      try fileManager.createDirectory(at: fatArchivesDir, withIntermediateDirectories: true)
      // Remove any previously built fat archives.
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }

      try FileManager.default.copyItem(at: fromFolder, to: destination)
    } catch {
      fatalError("Could not create directories needed to build \(framework): \(error)")
    }

    let fatArchive = fatArchivesDir.appendingPathComponent(framework)
    let result = syncExec(command: "/usr/bin/lipo", args: ["-create", "-output", fatArchive.path] + thinPaths)
    switch result {
    case let .error(code, output):
      fatalError("""
      lipo command exited with \(code) when trying to build \(framework). Output:
      \(output)
      """)
    case .success:
      print("lipo command for \(framework) succeeded.")
    }

    // Copy the built binary to the destination.
    let archiveDestination = destination.appendingPathComponent(framework)
    do {
      try FileManager.default.copyItem(at: fatArchive, to: archiveDestination)
    } catch {
      fatalError("Could not copy \(framework) to destination: \(error)")
    }
  }

  /// Packages an XCFramework based on an almost complete framework folder (missing the binary but includes everything else needed)
  /// and thin archives for each architecture slice.
  /// - Parameter fromFolder: The almost complete framework folder. Includes everything but the binary.
  /// - Parameter thinArchives: All the thin archives.
  private func packageXCFramework(withName framework: String,
                                  fromFolder: URL,
                                  thinArchives: [Architecture: URL]) -> URL {
    let fileManager = FileManager.default

    // Create a `.framework` for each of the thinArchives using the `fromFolder` as the base.
    let platformFrameworksDir =
      fileManager.temporaryDirectory(withName: "platform_frameworks")
    if !fileManager.directoryExists(at: platformFrameworksDir) {
      do {
        try fileManager.createDirectory(at: platformFrameworksDir,
                                        withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create a temp directory to store all thin frameworks: \(error)")
      }
    }

    // Group the thin frameworks into three groups: device, simulator, and Catalyst (all represented
    // by the `TargetPlatform` enum. The slices need to be packaged that way with lipo before
    // creating a .framework that works for similar grouped architectures. If built separately,
    // `-create-xcframework` will return an error and fail:
    // `Both ios-arm64 and ios-armv7 represent two equivalent library definitions`
    var frameworksBuilt: [URL] = []
    for platform in Architecture.TargetPlatform.allCases {
      // Get all the slices that belong to the specific platform in order to lipo them together.
      let slices = thinArchives.filter { $0.key.platform == platform }
      let platformDir = platformFrameworksDir.appendingPathComponent(platform.rawValue)
      do {
        try fileManager.createDirectory(at: platformDir, withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create directory for architecture slices on \(platform) for " +
          "\(framework): \(error)")
      }

      // Package a normal .framework with the given slices.
      let destination = platformDir.appendingPathComponent(fromFolder.lastPathComponent)
      packageFramework(withName: framework,
                       fromFolder: fromFolder,
                       thinArchives: slices,
                       destination: destination)

      frameworksBuilt.append(destination)
    }

    // We now need to package those built frameworks into an XCFramework.
    let xcframeworksDir = projectDir.appendingPathComponent("xcframeworks")
    if !fileManager.directoryExists(at: xcframeworksDir) {
      do {
        try fileManager.createDirectory(at: xcframeworksDir,
                                        withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create XCFrameworks directory: \(error)")
      }
    }

    let xcframework = xcframeworksDir.appendingPathComponent(framework + ".xcframework")
    if fileManager.fileExists(atPath: xcframework.path) {
      try! fileManager.removeItem(at: xcframework)
    }

    // The arguments for the frameworks need to be separated.
    var frameworkArgs: [String] = []
    for frameworkBuilt in frameworksBuilt {
      frameworkArgs.append("-framework")
      frameworkArgs.append(frameworkBuilt.path)
    }

    let outputArgs = ["-output", xcframework.path]
    let result = syncExec(command: "/usr/bin/xcodebuild",
                          args: ["-create-xcframework"] + frameworkArgs + outputArgs,
                          captureOutput: true)
    switch result {
    case let .error(code, output):
      fatalError("Could not build xcframework for \(framework) exit code \(code): \(output)")

    case .success:
      print("XCFramework for \(framework) built successfully at \(xcframework).")
    }

    return xcframework
  }

  /// Recrusively copies headers from the given directory to the destination directory. This does a
  /// deep copy and resolves and symlinks (which CocoaPods uses in the Public headers folder).
  /// Throws FileManager errors if something goes wrong during the operations.
  /// Note: This is only needed now because the `cp` command has a flag that did this for us, but
  /// FileManager does not.
  private func recursivelyCopyHeaders(from headersDir: URL,
                                      to destinationDir: URL,
                                      fileManager: FileManager = FileManager.default) throws {
    // Copy the public headers into the new framework. Unfortunately we can't just copy the
    // `Headers` directory since it uses aliases, so we'll recursively search the public Headers
    // directory from CocoaPods and resolve all the aliases manually.
    let fileManager = FileManager.default

    // Create the Headers directory if it doesn't exist.
    try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

    // Get all the header aliases from the CocoaPods directory and get their real path as well as
    // their relative path to the Headers directory they are in. This is needed to preserve proper
    // imports for nested folders.
    let aliasedHeaders = try fileManager.recursivelySearch(for: .headers, in: headersDir)
    let mappedHeaders: [(relativePath: String, resolvedLocation: URL)] = aliasedHeaders.map {
      // Standardize the URL because the aliasedHeaders could be at `/private/var` or `/var` which
      // are symlinked to each other on macOS. This will let us remove the `headersDir` prefix and
      // be left with just the relative path we need.
      let standardized = $0.standardizedFileURL
      let relativePath = standardized.path.replacingOccurrences(of: "\(headersDir.path)/", with: "")
      let resolvedLocation = standardized.resolvingSymlinksInPath()
      return (relativePath, resolvedLocation)
    }

    // Copy all the headers into the Headers directory created above.
    for (relativePath, location) in mappedHeaders {
      // Append the proper filename to our Headers directory, then try copying it over.
      let finalPath = destinationDir.appendingPathComponent(relativePath)

      // Create the destination folder if it doesn't exist.
      let parentDir = finalPath.deletingLastPathComponent()
      if !fileManager.directoryExists(at: parentDir) {
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
      }

      try fileManager.copyItem(at: location, to: finalPath)
    }
  }
}
