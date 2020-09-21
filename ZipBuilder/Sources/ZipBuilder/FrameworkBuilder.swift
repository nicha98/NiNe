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
  enum TargetPlatform: String {
    case device = "iphoneos"
    case simulator = "iphonesimulator"

    /// Arguments that should be included as part of the build process for each target platform.
    func extraArguments() -> [String] {
      switch self {
      case .device:
        // For device, we want to enable bitcode.
        return ["OTHER_CFLAGS=$(value) " + "-fembed-bitcode"]
      case .simulator:
        // No extra arguments are required for simulator builds.
        return []
      }
    }
  }

  case arm64
  case armv7
  case i386
  case x86_64

  /// The platform associated with the architecture.
  var platform: TargetPlatform {
    switch self {
    case .arm64, .armv7: return .device
    case .i386, .x86_64: return .simulator
    }
  }
}

/// A structure to build a .framework in a given project directory.
struct FrameworkBuilder {
  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// The Pods directory for building the framework.
  private var podsDir: URL {
    return projectDir.appendingPathComponent("Pods", isDirectory: true)
  }

  /// Default initializer.
  init(projectDir: URL) {
    self.projectDir = projectDir
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
  /// - Returns: A URL to the framework that was built (or pulled from the cache) and a URL to the
  ///     Resources directory containing all required bundles.
  public func buildFramework(withName podName: String,
                             version: String,
                             cacheKey: String?,
                             cacheEnabled: Bool = false) -> (framework: URL, resources: URL) {
    print("Building \(podName)")

    // Get the CocoaPods cache to see if we can pull from any frameworks already built.
    let podsCache = CocoaPodUtils.listPodCache(inDir: projectDir)

    guard let cachedVersions = podsCache[podName] else {
      fatalError("Cannot find a pod cache for framework \(podName).")
    }

    guard let podInfo = cachedVersions[version] else {
      fatalError("""
      Cannot find a pod cache for framework \(podName) at version \(version).
      Something could be wrong with your CocoaPods cache - try running the following:

      pod cache clean '\(podName)' --all
      """)
    }

    // TODO: Figure out if we need the MD5 at all.
    let md5 = Shell.calculateMD5(for: podInfo.installedLocation)

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
    let cachedResourcesDir = cachedFrameworkRoot.appendingPathComponent("Resources")
    if cachedFrameworkExists, cacheEnabled {
      print("Framework \(podName) version \(version) has already been built and cached at " +
        "\(cachedFrameworkDir)")
      return (cachedFrameworkDir, cachedResourcesDir)
    } else {
      let (frameworkDir, bundles) = compileFrameworkAndResources(withName: podName)
      do {
        // Remove the previously cached framework, if it exists, otherwise the `moveItem` call will
        // fail.
        if cachedFrameworkExists {
          try fileManager.removeItem(at: cachedFrameworkDir)
        } else if !fileManager.directoryExists(at: cachedFrameworkRoot) {
          // If the root directory doesn't exist, create it so the `moveItem` will succeed.
          try fileManager.createDirectory(at: cachedFrameworkRoot,
                                          withIntermediateDirectories: true,
                                          attributes: nil)
        }

        // Move any Resource bundles into the Resources folder. Remove the existing Resources folder
        // and create a new one.
        if fileManager.directoryExists(at: cachedResourcesDir) {
          try fileManager.removeItem(at: cachedResourcesDir)
        }

        // Create the directory where all the bundles will be kept and copy each one.
        try fileManager.createDirectory(at: cachedResourcesDir,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        for bundle in bundles {
          let destination = cachedResourcesDir.appendingPathComponent(bundle.lastPathComponent)
          try fileManager.moveItem(at: bundle, to: destination)
        }

        // Move the newly built framework to the cache directory. NOTE: This needs to happen after
        // the Resources are moved since the Resources are contained in the frameworkDir.
        try fileManager.moveItem(at: frameworkDir, to: cachedFrameworkDir)

        return (cachedFrameworkDir, cachedResourcesDir)
      } catch {
        fatalError("Could not move built frameworks into the cached frameworks directory: \(error)")
      }
    }
  }

  // MARK: - Private Helpers

  /// This runs a command and immediately returns a Shell result.
  /// NOTE: This exists in conjunction with the `Shell.execute...` due to issues with different
  ///       `.bash_profile` environment variables. This should be consolidated in the future.
  private func syncExec(command: String, args: [String] = []) -> Shell.Result {
    let task = Process()
    task.launchPath = command
    task.arguments = args
    task.launch()
    task.waitUntilExit()
//
//    var pipe = Pipe()
//    task.standardOutput = pipe
//    let handle = pipe.fileHandleForReading

    // Normally we'd use a pipe to retrieve the output, but for whatever reason it slows things down
    // tremendously for xcodebuild.
    let output = "The task completed."
    guard task.terminationStatus == 0 else {
      return .error(code: task.terminationStatus, output: output)
    }

    return .success(output: output)
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
    let platform = arch.platform
    let workspacePath = projectDir.appendingPathComponent("FrameworkMaker.xcworkspace").path
    let standardOptions = ["build",
                           "-configuration", "release",
                           "-workspace", workspacePath,
                           "-scheme", framework,
                           "GCC_GENERATE_DEBUGGING_SYMBOLS=No",
                           "ARCHS=\(arch.rawValue)",
                           "BUILD_DIR=\(buildDir.path)",
                           "-sdk", platform.rawValue]
    let args = standardOptions + platform.extraArguments()
    print("""
    Compiling \(framework) for \(arch.rawValue) with command:
    /usr/bin/xcodebuild \(args.joined(separator: " "))
    """)

    // Regardless if it succeeds or not, we want to write the log to file in case we need to inspect
    // things further.
    let logFileName = "\(framework)-\(arch.rawValue)-\(platform.rawValue).txt"
    let logFile = logRoot.appendingPathComponent(logFileName)

    let result = syncExec(command: "/usr/bin/xcodebuild", args: args)
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

  private func makeModuleMap(baseDir: URL, framework: String, dir: URL) {
    let dependencies = getModuleDependencies(forFramework: framework)
    let moduleDir = dir.appendingPathComponent("Modules")
    do {
      try FileManager.default.createDirectory(at: moduleDir,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    } catch {
      fatalError("Could not create Modules directory for framework: \(framework). \(error)")
    }

    let modulemap = moduleDir.appendingPathComponent("module.modulemap")
    // The base of the module map. The empty line at the end is intentional, do not remove it.
    var content = """
    framework module \(framework) {
    umbrella header "\(framework).h"
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
  /// - Returns: A path to the newly compiled framework and Resource bundles.
  private func compileFrameworkAndResources(withName framework: String) ->
    (framework: URL, resourceBundles: [URL]) {
    let fileManager = FileManager.default
    let outputDir = fileManager.temporaryDirectory(withName: "frameworkBeingBuilt")
    let logsDir = fileManager.temporaryDirectory(withName: "buildLogs")
    do {
      // Remove the compiled frameworks directory, this isn't the cache we're using.
      if fileManager.directoryExists(at: outputDir) {
        try fileManager.removeItem(at: outputDir)
      }

      try fileManager.createDirectory(at: outputDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)

      // Create our logs directory if it doesn't exist.
      if !fileManager.directoryExists(at: logsDir) {
        try fileManager.createDirectory(at: logsDir,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
      }
    } catch {
      fatalError("Failure creating temporary directory while building \(framework): \(error)")
    }

    // Build every architecture and save the locations in an array to be assembled.
    // TODO: Pass in supported architectures here, for those that don't support individual
    // architectures (MLKit).
    var thinArchives = [URL]()
    for arch in Architecture.allCases {
      let buildDir = projectDir.appendingPathComponent(arch.rawValue)
      let thinArchive = buildThin(framework: framework,
                                  arch: arch,
                                  buildDir: buildDir,
                                  logRoot: logsDir)
      thinArchives.append(thinArchive)
    }

    // Create the framework directory in the filesystem for the thin archives to go.
    let frameworkDir = outputDir.appendingPathComponent("\(framework).framework")
    do {
      try fileManager.createDirectory(at: frameworkDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    } catch {
      fatalError("Could not create framework directory while building framework \(framework). " +
        "\(error)")
    }

    // Build the fat archive using the `lipo` command. We need the full archive path and the list of
    // thin paths (as Strings, not URLs).
    let thinPaths = thinArchives.map { $0.path }
    let fatArchive = frameworkDir.appendingPathComponent(framework)
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

    // Remove the temporary thin archives.
    for thinArchive in thinArchives {
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

    // Verify Firebase headers include an explicit umbrella header for Firebase.h.
    let headersDir = podsDir.appendingPathComponents(["Headers", "Public", framework])
    if framework.hasPrefix("Firebase") {
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
    let bundles: [URL]
    do {
      bundles = try ResourcesManager.moveAllBundles(inDirectory: contentsDir, to: resourceDir)
    } catch {
      fatalError("Could not move bundles into Resources directory while building \(framework): " +
        "\(error)")
    }

    makeModuleMap(baseDir: outputDir, framework: framework, dir: frameworkDir)
    return (frameworkDir, bundles)
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
    try fileManager.createDirectory(at: destinationDir,
                                    withIntermediateDirectories: true,
                                    attributes: nil)

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
        try fileManager.createDirectory(at: parentDir,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
      }

      print("Attempting to copy \(location) to \(finalPath)")
      try fileManager.copyItem(at: location, to: finalPath)
    }
  }
}
