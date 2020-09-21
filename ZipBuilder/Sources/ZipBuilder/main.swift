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

// Get the launch arguments, parsed by user defaults.
let args = LaunchArgs()

// Clear the cache if requested.
if args.deleteCache {
  do {
    let cacheDir = try FileManager.default.firebaseCacheDirectory()
    try FileManager.default.removeItem(at: cacheDir)
  } catch {
    fatalError("Could not empty the cache before building the zip file: \(error)")
  }
}

// Keep timing for how long it takes to build the zip file for information purposes.
let buildStart = Date()
var cocoaPodsUpdateMessage: String = ""

// Do a Pod Update if requested.
if args.updatePodRepo {
  CocoaPodUtils.updateRepos()
  cocoaPodsUpdateMessage = "CocoaPods took \(-buildStart.timeIntervalSinceNow) seconds to update."
}

var paths = ZipBuilder.FilesystemPaths(templateDir: args.templateDir,
                                       coreDiagnosticsDir: args.coreDiagnosticsDir)
paths.allSDKsPath = args.allSDKsPath
paths.currentReleasePath = args.currentReleasePath
let builder = ZipBuilder(paths: paths,
                         customSpecRepos: args.customSpecRepos,
                         useCache: args.cacheEnabled)

do {
  // Build the zip file and get the path.
  let location = try builder.buildAndAssembleZipDir()
  print("Location of directory to be Zipped: \(location)")

  print("Attempting to Zip the directory...")
  let zipped = Zip.zipContents(ofDir: location)

  // If an output directory was specified, copy the Zip file to that directory. Otherwise just print
  // the location for further use.
  if let outputDir = args.outputDir {
    do {
      let destination = outputDir.appendingPathComponent(zipped.lastPathComponent)
      try FileManager.default.copyItem(at: zipped, to: destination)
    } catch {
      fatalError("Could not copy Zip file to output directory: \(error)")
    }
  } else {
    print("Success! Zip file can be found at \(zipped.path)")
  }

  // Get the time since the start of the build to get the full time.
  let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
  print("""
  Time profile:
    It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to build the zip file.
    \(cocoaPodsUpdateMessage)
  """)
} catch {
  let secondsSinceStart = -buildStart.timeIntervalSinceNow
  print("""
  Time profile:
    The build failed in \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m).
    \(cocoaPodsUpdateMessage)
  """)
  fatalError("Could not build the zip file: \(error)")
}
