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

/// Misc. constants used in the script.
private struct Constants {
  /// Constants related to the Xcode project template.
  public struct ProjectPath {
    // Required for building.
    public static let infoPlist = "Info.plist"
    public static let projectFile = "FrameworkMaker.xcodeproj"

    /// All required files for building the Zip file.
    public static let requiredFilesForBuilding: [String] = [projectFile, infoPlist]

    // Required for distribution.
    public static let firebaseHeader = "Firebase.h"
    public static let readmeName = "README.md"
    public static let modulemap = "module.modulemap"
    public static let notices = "NOTICES"

    // Directory containing extra FirebaseCrash scripts.
    public static let crashDir = "Crash"

    /// All required files for distribution. Note: the readmeTemplate is also needed for
    /// distribution but is copied separately since it's modified.
    public static let requiredFilesForDistribution: [String] = [firebaseHeader, modulemap, notices]

    // Make the struct un-initializable.
    @available(*, unavailable)
    init() { fatalError() }
  }

  /// The text added to the README for a product if it contains Resources. The empty line at the end
  /// is intentional.
  public static let resourcesRequiredText = """
  You'll also need to add the resources in the Resources
  directory into your target's main bundle.

  """

  // Make the struct un-initializable.
  @available(*, unavailable)
  init() { fatalError() }
}

/// A package of files to install for a specific Pod. Used for closed source SDKs in the framework
/// generation step to determine the files required during packaging.
private struct FilesToInstall {
  /// All frameworks required for the product to function.
  let frameworks: [URL]
  /// Any resources required for the product.
  let resourceBundles: [URL]

  /// Default initializer.
  init(frameworks: [URL], resourceBundles: [URL] = []) {
    self.frameworks = frameworks
    self.resourceBundles = resourceBundles
  }
}

/// A zip file builder. The zip file can be built with the `build()` function.
struct ZipBuilder {
  struct FilesystemPaths {
    // MARK: - Required Paths

    /// The path to the CoreDiagnostics.framework directory with the Zip flag enabled.
    var coreDiagnosticsDir: URL

    /// The path to the directory containing the blank xcodeproj and Info.plist for building source
    /// based frameworks.
    var templateDir: URL

    // MARK: - Optional Paths

    /// A file URL to a textproto with the contents of a `ZipBuilder_FirebaseSDKs` object. Used to
    /// verify expected version numbers.
    var allSDKsPath: URL?

    /// A file URL to a textproto with the contents of a `ZipBuilder_Release` object. Used to verify
    /// expected version numbers.
    var currentReleasePath: URL?

    /// Default initializer with all required paths.
    init(templateDir: URL, coreDiagnosticsDir: URL) {
      self.templateDir = templateDir
      self.coreDiagnosticsDir = coreDiagnosticsDir
    }
  }

  /// Custom CocoaPods spec repos to be used. If not provided, the tool will only use the CocoaPods
  /// master repo.
  private let customSpecRepos: [URL]?

  /// Paths needed throughout the process of packaging the Zip file.
  private let paths: FilesystemPaths

  /// Determines if the cache should be used or not.
  private let useCache: Bool

  /// Default initializer. If allSDKsPath and currentReleasePath are provided, it will also verify
  /// that the
  ///
  /// - Parameters:
  ///   - paths: Paths that are needed throughout the process of packaging the Zip file.
  ///   - customSpecRepo: A custom spec repo to be used for fetching CocoaPods from.
  ///   - useCache: Enables or disables the cache.
  init(paths: FilesystemPaths,
       customSpecRepos: [URL]? = nil,
       useCache: Bool = false) {
    self.paths = paths
    self.customSpecRepos = customSpecRepos
    self.useCache = useCache
  }

  /// Try to build and package the contents of the Zip file. This will throw an error as soon as it
  /// encounters an error, or will quit due to a fatal error with the appropriate log.
  ///
  /// - Returns: A URL to the folder that should be compressed and distributed.
  /// - Throws: One of many errors that could have happened during the build phase.
  func buildAndAssembleZipDir() throws -> URL {
    let projectDir = FileManager.default.temporaryDirectory(withName: "project")

    // If it exists, remove it before we re-create it. This is simpler than removing all objects.
    if FileManager.default.directoryExists(at: projectDir) {
      try FileManager.default.removeItem(at: projectDir)
    }

    do {
      // Create the directory and all intermediate directories.
      try FileManager.default.createDirectory(at: projectDir,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    } catch {
      // Use `do/catch` instead of `guard let tempDir = try?` so we can print the error thrown.
      fatalError("Cannot create temporary directory at beginning of script: \(error)")
    }

    // Copy the Xcode project needed in order to be able to install Pods there.
    let templateFiles = Constants.ProjectPath.requiredFilesForBuilding.map {
      paths.templateDir.appendingPathComponent($0)
    }
    for file in templateFiles {
      // Each file should be copied to the temporary project directory with the same name.
      let destination = projectDir.appendingPathComponent(file.lastPathComponent)
      do {
        if !FileManager.default.fileExists(atPath: destination.path) {
          print("Copying template file \(file) to \(destination)...")
          try FileManager.default.copyItem(at: file, to: destination)
        }
      } catch {
        fatalError("Could not copy template project to temporary directory in order to install " +
          "pods. Failed while attempting to copy \(file) to \(destination). \(error)")
      }
    }

    // Get the README template ready (before attempting to build everything in case this fails,
    // otherwise debugging it will take a long time).
    let readmePath = paths.templateDir.appendingPathComponent(Constants.ProjectPath.readmeName)
    let readmeTemplate: String
    do {
      readmeTemplate = try String(contentsOf: readmePath)
    } catch {
      fatalError("Could not get contents of the README template: \(error)")
    }

    // Break the `subspecsToInstall` into a variable since it's helpful when debugging non-cache
    // builds to just install a subset: `[.core, .analytics, .storage, .firestore]` for example.
    let subspecsToInstall = Subspec.allCases

    // We need to install all the subpsecs in order to get every single framework that we'll need
    // for the zip file. We can't install each one individually since some pods depend on different
    // subspecs from the same pod (ex: GoogleUtilities, GoogleToolboxForMac, etc). All of the code
    // wouldn't be included so we need to install all of the subspecs to catch the superset of all
    // required frameworks, then use that as the source of frameworks to pull from when including
    // the folders in each product directory.
    CocoaPodUtils.installSubspecs(subspecsToInstall,
                                  inDir: projectDir,
                                  customSpecRepos: customSpecRepos)

    // If any expected versions were passed in, we should verify that those were actually installed
    // and get the list of actual versions we'll be using to build the Zip file. This method will
    // throw a fatalError if any versions are mismatched.
    validateExpectedVersions(inProjectDir: projectDir)

    let installedPods = CocoaPodUtils.installedPodsInfo(inProjectDir: projectDir)
    let filesToInstall = generateFrameworksWithResources(fromPods: installedPods,
                                                         inProjectDir: projectDir,
                                                         useCache: useCache)

    // Create an array that has the Pod name as the key and the array of frameworks needed - this
    // will be used as the source of truth for all frameworks to be copied in each product's
    // directory.
    let frameworks = filesToInstall.mapValues { $0.frameworks }
    for (framework, paths) in frameworks {
      print("Frameworks for pod: \(framework) were compiled at \(paths)")
    }

    // TODO: Overwrite the `CoreDiagnostics.framework` in the generated framework.

    // TODO: The folder heirarchy should change in Firebase 6.
    // Time to assemble the folder structure of the Zip file. In order to get the frameworks
    // required, we will `pod install` only those subspecs and then fetch the information for all
    // the frameworks that were installed, copying the frameworks from our list of compiled
    // frameworks. The whole process is:
    // 1. Copy any required files (headers, modulemap, etc) over beforehand to fail fast if anything
    //    is misconfigured.
    // 2. Get the frameworks required for Analytics, copy them to the Analytics folder.
    // 3. Go through the rest of the subspecs (excluding those included in Analytics) and copy them
    //    to a folder with the name of the subspec.
    // 4. Assemble the `README` file based off the template and copy it to the directory.
    // 5. Return the URL of the folder containing the contents of the Zip file.

    // Create the directory that will hold all the contents of the Zip file.
    let zipDir = FileManager.default.temporaryDirectory(withName: "Firebase")
    do {
      if FileManager.default.directoryExists(at: zipDir) {
        try FileManager.default.removeItem(at: zipDir)
      }

      try FileManager.default.createDirectory(at: zipDir,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    }

    // Copy all the other required files to the Zip directory.
    let distributionFiles = Constants.ProjectPath.requiredFilesForDistribution.map {
      paths.templateDir.appendingPathComponent($0)
    }
    for file in distributionFiles {
      // Each file should be copied to the destination project directory with the same name.
      let destination = zipDir.appendingPathComponent(file.lastPathComponent)
      do {
        if !FileManager.default.fileExists(atPath: destination.path) {
          print("Copying final distribution file \(file) to \(destination)...")
          try FileManager.default.copyItem(at: file, to: destination)
        }
      } catch {
        fatalError("Could not copy final distribution files to temporary directory before " +
          "building. Failed while attempting to copy \(file) to \(destination). \(error)")
      }
    }

    // Start with installing Analytics, since we'll need to exclude those frameworks from the rest
    // of the folders.
    let analyticsFrameworks: [String]
    let analyticsDir: URL
    do {
      // This returns the Analytics directory and a list of framework names that Analytics reqires.
      /// Example: ["FirebaseInstanceID", "GoogleAppMeasurement", "nanopb", <...>]
      let (dir, frameworks) = try installAndCopyFrameworks(forSubspec: .analytics,
                                                           projectDir: projectDir,
                                                           rootZipDir: zipDir,
                                                           builtFrameworks: frameworks)
      analyticsFrameworks = frameworks
      analyticsDir = dir
    } catch {
      fatalError("Could not copy frameworks from Analytics into the zip file: \(error)")
    }

    // Start the README dependencies string with the frameworks built in Analytics.
    var readmeDeps = dependencyString(for: .analytics,
                                      in: analyticsDir,
                                      frameworks: analyticsFrameworks)

    // Loop through all the other subspecs that aren't Core and Analytics and write them to their
    // final destination, including resources.
    let resourceBundles = filesToInstall.mapValues({ $0.resourceBundles }).filter({ !$0.value.isEmpty })
    let remainingSubspecs = subspecsToInstall.filter { $0 != .analytics && $0 != .core }
    for spec in remainingSubspecs {
      do {
        let (specDir, podFrameworks) =
          try installAndCopyFrameworks(forSubspec: spec,
                                       projectDir: projectDir,
                                       rootZipDir: zipDir,
                                       builtFrameworks: frameworks,
                                       podsToIgnore: analyticsFrameworks,
                                       foldersToIgnore: spec.duplicateFrameworksToRemove())

        // Copy any Resources from closed source pods into their destination folder. Open source
        // pods have already had the Resources taken care of.
        for pod in podFrameworks {
          guard let bundles = resourceBundles[pod] else { continue }

          // If Resources should be excluded (for example from MLKit), move on to the next one.
          guard !spec.excludeResources else { continue }

          // There are bundles to copy! Create a Resources directory.
          let resourceDir = specDir.appendingPathComponent("Resources", isDirectory: true)
          try FileManager.default.createDirectory(at: resourceDir,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)

          // Copy each bundle individually, skipping duplicates.
          let bundlesToSkip = spec.duplicateResourcesToRemove()
          for bundle in bundles {
            let name = bundle.lastPathComponent
            guard !bundlesToSkip.contains(name) else { continue }

            let destination = resourceDir.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.copyItem(at: bundle, to: destination)
          }
        }

        readmeDeps += dependencyString(for: spec, in: specDir, frameworks: podFrameworks)
      } catch {
        fatalError("Could not copy frameworks from \(spec.rawValue) into the zip file: \(error)")
      }
    }

    // Assemble the README. Start with the version text, then use the template to inject the
    // versions and the list of frameworks to include for each pod.
    let versionsText = versionsString(for: installedPods)
    let readmeText = readmeTemplate.replacingOccurrences(of: "__INTEGRATION__", with: readmeDeps)
      .replacingOccurrences(of: "__VERSIONS__", with: versionsText)
    do {
      try readmeText.write(to: zipDir.appendingPathComponent(Constants.ProjectPath.readmeName),
                           atomically: true,
                           encoding: .utf8)
    } catch {
      fatalError("Could not write README to Zip directory: \(error)")
    }

    // TODO: Remove this manual copy once FirebaseCrash is removed from the Zip file.
    // Copy over the Crash scripts, if Crash should be installed
    if subspecsToInstall.contains(.crash) {
      do {
        let crashDir = paths.templateDir.appendingPathComponent(Constants.ProjectPath.crashDir)
        let crashFiles = try FileManager.default.contentsOfDirectory(at: crashDir,
                                                                     includingPropertiesForKeys: nil,
                                                                     options: [])
        let crashZipDir = zipDir.appendingPathComponent("Crash")
        for file in crashFiles {
          let destination = crashZipDir.appendingPathComponent(file.lastPathComponent)
          try FileManager.default.copyItem(at: file, to: destination)
        }
      } catch {
        fatalError("Could not copy extra Crash tools: \(error)")
      }
    }

    print("Contents of the Zip file were assembled at: \(zipDir)")
    return zipDir
  }

  // MARK: - Private

  /// Copies all frameworks from the `InstalledPod` (pulling from the `frameworkLocations`) and copy
  /// them to the destination directory.
  ///
  /// - Parameters:
  ///   - installedPods: All the Pods installed for a given set of subspecs, which will be used as a
  ///               list to find out what frameworks to copy to the destination.
  ///   - dir: Destination directory for all the frameworks.
  ///   - frameworkLocations: A dictionary containing the pod name as the key and a location to
  ///                         the compiled frameworks.
  ///   - ignoreFrameworks: A list of Pod
  /// - Throws: Various FileManager errors in case the copying fails, or an error if the framework
  //            doesn't exist in `frameworkLocations`.
  private func copyFrameworks(fromPods installedPods: [CocoaPodUtils.PodInfo],
                              toDirectory dir: URL,
                              frameworkLocations: [String: [URL]],
                              podsToIgnore: [String],
                              foldersToIgnore: [String]) throws {
    let fileManager = FileManager.default
    if !fileManager.directoryExists(at: dir) {
      try fileManager.createDirectory(at: dir, withIntermediateDirectories: false, attributes: nil)
    }

    // Loop through each InstalledPod item and get the name so we can fetch the framework and copy
    // it to the destination directory.
    for pod in installedPods {
      // Skip the Firebase pod, any Interop pods, and specifically ignored frameworks.
      guard pod.name != "Firebase",
        !pod.name.contains("Interop"),
        !podsToIgnore.contains(pod.name) else {
        continue
      }

      guard let frameworks = frameworkLocations[pod.name] else {
        let reason = "Unable to find frameworks for \(pod.name) in cache of frameworks built to " +
          "include in the Zip file for that framework's folder."
        let error = NSError(domain: "com.firebase.zipbuilder",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: reason])
        throw error
      }

      // Copy each of the frameworks over, unless it's explicitly ignored.
      for framework in frameworks {
        let frameworkName = framework.lastPathComponent
        if foldersToIgnore.contains(frameworkName) {
          continue
        }

        let destination = dir.appendingPathComponent(frameworkName)
        try fileManager.copyItem(at: framework, to: destination)
      }
    }
  }

  /// Creates the String required for this subspec to be added to the README. Creates a header and
  /// lists each framework in alphabetical order with the appropriate indentation, as well as a
  /// message about resources if they exist.
  ///
  /// - Parameters:
  ///   - subspec: The subspec that requires documentation.
  ///   - dir: The directory where everything lives. Used to check if the spec has resources.
  ///   - frameworks: All the frameworks required by the subspec.
  /// - Returns: A string with a header for the subspec name, and a list of frameworks required to
  ///            integrate for the product to work. Formatted and ready for insertion into the
  ///            README.
  private func dependencyString(for subspec: Subspec, in dir: URL, frameworks: [String]) -> String {
    var result = subspec.readmeHeader()
    for framework in frameworks.sorted() {
      result += "- \(framework).framework\n"
    }

    result += "\n"

    // Check if there is a Resources directory, and if so, add the disclaimer to the dependency
    // string.
    do {
      let fileManager = FileManager.default
      let resourceDirs = try fileManager.recursivelySearch(for: .directories(name: "Resources"),
                                                           in: dir)
      if !resourceDirs.isEmpty {
        result += Constants.resourcesRequiredText
      }
    } catch {
      fatalError("""
      Tried to find Resources directory for \(subspec) in order to build the README, but an error
      occurred: \(error).
      """)
    }

    return result
  }

  /// Assembles the expected versions based on the release manifests passed in, if they were.
  /// Returns an array with the SDK name as the key and version as the value,
  private func expectedVersions() -> [String: String] {
    // Merge the versions from the current release and the known public versions.
    var releasingVersions: [String: String] = [:]

    // Check the existing expected versions and build a dictionary out of the expected versions.
    if let sdksPath = paths.allSDKsPath {
      let allSDKs = ManifestReader.loadAllReleasedSDKs(fromTextproto: sdksPath)
      print("Parsed the following SDKs from the public release manifest:")

      for sdk in allSDKs.sdk {
        releasingVersions[sdk.name] = sdk.publicVersion
        print("\(sdk.name): \(sdk.publicVersion)")
      }
    }

    // Override any of the expected versions with the current release manifest, if it exists.
    if let releasePath = paths.currentReleasePath {
      let currentRelease = ManifestReader.loadCurrentRelease(fromTextproto: releasePath)
      print("Overriding the following SDKs, taken from the current release manifest:")
      for sdk in currentRelease.sdk {
        releasingVersions[sdk.sdkName] = sdk.sdkVersion
        print("\(sdk.sdkName): \(sdk.sdkVersion)")
      }
    }

    if !releasingVersions.isEmpty {
      print("Final expected versions for the Zip file: \(releasingVersions)")
    }

    return releasingVersions
  }

  /// Installs a subspec and attempts to copy all the frameworks required for it from
  /// `buildFramework` and puts them into a new directory in the `rootZipDir` matching the
  /// subspec's name. This also will move any Resources directory outside of the frameworks and
  /// place them in the same directory as the rest of the frameworks.
  ///
  /// - Parameters:
  ///   - subspec: The subspec to install and get the dependencies list.
  ///   - projectDir: Root of the project containing the Podfile.
  ///   - rootZipDir: The root directory to be turned into the Zip file.
  ///   - builtFrameworks: All frameworks that have been built, with the framework name as the key
  ///                      and the framework's location as the value.
  ///   - podsToIgnore: Pods to avoid copying, if any.
  ///   - foldersToIgnore: Specific folders to avoid copying, if any.
  /// - Throws: Throws various errors from copying frameworks.
  /// - Returns: The directory containing all the frameworks and the names of the frameworks that
  ///            were copied for this subspec.
  @discardableResult
  func installAndCopyFrameworks(
    forSubspec subspec: Subspec,
    projectDir: URL,
    rootZipDir: URL,
    builtFrameworks: [String: [URL]],
    podsToIgnore: [String] = [],
    foldersToIgnore: [String] = []
  ) throws -> (output: URL, frameworks: [String]) {
    let installedPods = CocoaPodUtils.installSubspecs([subspec], inDir: projectDir, customSpecRepos: customSpecRepos)
    let productDir = rootZipDir.appendingPathComponent(subspec.rawValue)
    try copyFrameworks(fromPods: installedPods,
                       toDirectory: productDir,
                       frameworkLocations: builtFrameworks,
                       podsToIgnore: podsToIgnore,
                       foldersToIgnore: foldersToIgnore)

    // Return the names of all the installed frameworks.
    let namedFrameworks = installedPods.map { $0.name }
    let copiedFrameworks = namedFrameworks.filter {
      // Only return the frameworks that aren't contained in the "podsToIgnore" array, aren't an
      // interop framework (since they don't compile to frameworks), or the Firebase pod itself.
      !(podsToIgnore.contains($0) || $0.hasSuffix("Interop") || $0 == "Firebase")
    }

    return (productDir, copiedFrameworks)
  }

  /// Validates that the expected versions (based on the release manifest passed in, if there was
  /// one) match the expected versions installed and listed in the Podfile.lock in a project
  /// directory.
  ///
  /// - Parameter projectDir: The directory containing the Podfile.lock file of installed pods.
  private func validateExpectedVersions(inProjectDir projectDir: URL) {
    // Get the expected versions based on the release manifests, if there are any. We'll use this to
    // validate the versions pulled from CocoaPods. Expected versions could be empty, in which case
    // validation succeeds.
    let expected = expectedVersions()
    if !expected.isEmpty {
      // There are some expected versions, read from the CocoaPods Podfile.lock and grab the
      // installed versions.
      let podfileLock: String
      do {
        podfileLock = try String(contentsOf: projectDir.appendingPathComponent("Podfile.lock"))
      } catch {
        fatalError("Could not read contents of `Podfile.lock` to validate versions in " +
          "\(projectDir): \(error)")
      }

      // Get the versions in the format of [PodName: VersionString].
      let actual = CocoaPodUtils.loadVersionsFromPodfileLock(contents: podfileLock)

      // Loop through the expected versions and verify the actual versions match.
      for podName in expected.keys where !podName.contains("SmartReply") {
        guard let actualVersion = actual[podName],
          let expectedVersion = expected[podName],
          actualVersion == expectedVersion else {
          fatalError("""
          Version mismatch from expected versions and version installed in CocoaPods:
          Pod Name: \(podName)
          Expected Version: \(String(describing: expected[podName]))
          Actual Version: \(String(describing: actual[podName]))
          Please verify that the expected version is correct, and the Podspec dependencies are
          appropriately versioned.
          """)
        }

        print("Successfully verified version of \(podName) is \(actualVersion)")
      }
    }
  }

  /// Creates the String that displays all the versions of each pod, in alphabetical order.
  ///
  /// - Parameter pods: All pods that were installed, with their versions.
  /// - Returns: A String to be added to the README.
  private func versionsString(for pods: [CocoaPodUtils.PodInfo]) -> String {
    // Get the longest name in order to generate padding with spaces so it looks nicer.
    let maxLength: Int = {
      guard let pod = pods.max(by: { $0.name.count < $1.name.count }) else {
        // The longest pod as of this writing is 29 characters, if for whatever reason this fails
        // just assume 30 characters long.
        return 30
      }

      // Return room for a space afterwards.
      return pod.name.count + 1
    }()

    let header: String = {
      // Center the CocoaPods title within the spaces given. If there's an odd number of spaces, add
      // the extra space after the CocoaPods title.
      let cocoaPods = "CocoaPod"
      let spacesToPad = maxLength - cocoaPods.count
      let halfPadding = String(repeating: " ", count: spacesToPad / 2)

      // Start with the spaces padding, then add the CocoaPods title.
      var result = halfPadding + cocoaPods + halfPadding
      if spacesToPad % 2 != 0 {
        // Add an extra space since the padding isn't even
        result += " "
      }

      // Add the versioning text and return.
      result += "| Version\n"

      // Add a line underneath each.
      result += String(repeating: "-", count: maxLength) + "|" + String(repeating: "-", count: 9)
      result += "\n"
      return result
    }()

    // Sort the pods by name for a cleaner display.
    let sortedPods = pods.sorted { $0.name < $1.name }

    // Get the name and version of each pod, padding it along the way.
    var podVersions: String = ""
    for pod in sortedPods {
      // Insert the name and enough spaces to reach the end of the column.
      let podName = pod.name
      podVersions += podName + String(repeating: " ", count: maxLength - podName.count)

      // Add a pipe and the version.
      podVersions += "| " + pod.version + "\n"
    }

    return header + podVersions
  }

  // MARK: - Framework Generation

  /// Generates all the .framework files from a Pods directory. This will go through the contents of
  /// the directory, copy the .frameworks to a temporary directory and compile any source based
  /// CocoaPods. Returns a dictionary with the framework name for the key and all information for
  /// files to install (frameworks and resources).
  private func generateFrameworksWithResources(fromPods pods: [CocoaPodUtils.PodInfo],
                                               inProjectDir projectDir: URL,
                                               useCache: Bool = false) -> [String: FilesToInstall] {
    // Verify the Pods folder exists and we can get the contents of it.
    let fileManager = FileManager.default

    // Create the temporary directory we'll be storing the build/assembled frameworks in, and remove
    // the Resources directory if it already exists.
    let tempDir = fileManager.temporaryDirectory(withName: "all_frameworks")
    let tempResourceDir = tempDir.appendingPathComponent("Resources")
    do {
      try fileManager.createDirectory(at: tempDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
      if fileManager.directoryExists(at: tempResourceDir) {
        try fileManager.removeItem(at: tempResourceDir)
      }
    } catch {
      fatalError("Cannot create temporary directory to store frameworks and resources from the " +
        "full build: \(error)")
    }

    // Loop through each pod folder and check if the frameworks already exist, or they need to be
    // compiled. If they exist, add them to the frameworks dictionary.
    var toInstall: [String: FilesToInstall] = [:]
    for pod in pods {
      var frameworks: [URL] = []
      // Ignore any Interop pods or the Firebase umbrella pod.
      guard !pod.name.contains("Interop"), pod.name != "Firebase" else {
        continue
      }

      // Get all the frameworks contained in this directory.
      var foundFrameworks: [URL]
      do {
        foundFrameworks = try fileManager.recursivelySearch(for: .frameworks,
                                                            in: pod.installedLocation)
      } catch {
        fatalError("Cannot search for .framework files in Pods directory " +
          "\(pod.installedLocation): \(error)")
      }

      // Get the resulting folder that will contain all resources for that Pod.
      let podResourceDir = tempResourceDir.appendingPathComponent(pod.name)
      var resourceBundles: [URL] = []

      // If there are no frameworks, it's an open source pod and we need to compile the source to
      // get a framework.
      if foundFrameworks.isEmpty {
        let builder = FrameworkBuilder(projectDir: projectDir)
        let (framework, resourceDir) = builder.buildFramework(withName: pod.name,
                                                              version: pod.version,
                                                              cacheKey: pod.cacheKey,
                                                              cacheEnabled: useCache)

        // Move all the Resources that are contained in the resourceDir returned.
        do {
          resourceBundles = try ResourcesManager.moveAllBundles(inDirectory: resourceDir,
                                                                to: podResourceDir)
        } catch {
          fatalError("Could not move Resource bundles for \(pod.name): \(error)")
        }

        frameworks = [framework]
      } else {
        // Copy found frameworks to a known temporary directory, and store that location. Also move
        // the resources inside the .framework to be consistent with the compiled frameworks, which
        // they'll be moved out afterwards.
        for framework in foundFrameworks {
          // Copy it to the temporary directory and save it to our list of frameworks.
          let copiedLocation = tempDir.appendingPathComponent(framework.lastPathComponent)

          // Remove the framework if it exists since it could be out of date.
          fileManager.removeDirectoryIfExists(at: copiedLocation)
          do {
            try fileManager.copyItem(at: framework, to: copiedLocation)
          } catch {
            fatalError("Cannot copy framework at \(framework) to \(copiedLocation) while " +
              "attempting to generate frameworks. \(error)")
          }

          frameworks.append(copiedLocation)
        }

        // There are two sitautions for Resources in closed source Pods depending on what they use
        // in their Podspec. Pods can define either pre-built bundles or a list of files for any
        // number of bundles to be created. We'll search for any pre-built bundles, and if there
        // aren't any, look in all the included Pods to see if there are Resources folders
        // available to build bundles from. The latter is necessary for GoogleMobileVision and
        // MLKit.

        // Search for any pre-built bundles.
        do {
          resourceBundles = try ResourcesManager.moveAllBundles(inDirectory: pod.installedLocation,
                                                                to: podResourceDir)
        } catch {
          fatalError("Cannot move Resource bundles for \(pod.name): \(error)")
        }

        // Special case for MLKit *Model subspecs, explicitly copy directories from
        // GoogleMobileVision. This should be fixed in the future to pull all compiled resources
        // from Xcode's build directory.
        if pod.name == "FirebaseMLVisionTextModel" || pod.name == "FirebaseMLVisionFaceModel" {
          do {
            let podsDir = pod.installedLocation.deletingLastPathComponent()
            let gmvDir = podsDir.appendingPathComponent("GoogleMobileVision")
            resourceBundles = try ResourcesManager.createBundleForFoldersInResourcesDirs(
              containedIn: gmvDir, destinationDir: podResourceDir
            )
          } catch {
            fatalError("Could not generate Resource bundles for \(pod.name): \(error)")
          }
        }
      }

      let podFiles = FilesToInstall(frameworks: frameworks, resourceBundles: resourceBundles)
      toInstall[pod.name] = podFiles
    }

    return toInstall
  }
}
