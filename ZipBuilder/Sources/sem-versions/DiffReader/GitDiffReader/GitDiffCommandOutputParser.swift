/*
 * Copyright 2020 Google LLC
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

protocol GitDiffCommandOutputParserProtocol {
  func parseDiff() throws -> Diff
}

class GitDiffCommandOutputParser: GitDiffCommandOutputParserProtocol {
  let string: String
  init(string: String) {
    self.string = string
  }

  func parseDiff() throws -> Diff {
    if #available(OSX 10.15, *) {
      let scanner = Scanner(string: string)
      // Don't skip anything.
      scanner.charactersToBeSkipped = nil

      var files: [File] = []
      while !scanner.isAtEnd {
        let file = try scanFileDiff(scanner)
        files.append(file)
      }

      return Diff(files: files)
    } else {
      throw GitDiffCommandOutputParser.ParserError.unsupportedOSVersion
    }
  }

  @available(OSX 10.15, *)
  private func scanFileDiff(_ scanner: Scanner) throws -> File {
    // Scan a file header.
    let (oldPath, newPath) = try scanner.scanPaths()

    // Scan up to a next file header or the diff end to get the file diff content.
    if let fileDiffString = scanner.scanUpToPaths() {
      // Scan a file diff with a separate scanner.
      let fileDiffScanner = Scanner(string: fileDiffString)
      fileDiffScanner.charactersToBeSkipped = nil

      // Scan diff lines.
      var allDiffLines: [FileDiff.Line] = []
      while let lines = fileDiffScanner.scanChunkDiffLines() {
        allDiffLines += lines
      }

      let fileDiff = FileDiff(oldPath: oldPath, newPath: newPath, lines: allDiffLines)
      return File(path: newPath, diff: fileDiff)
    }

    let fileDiff = FileDiff(oldPath: oldPath, newPath: newPath, lines: [])
    return File(path: newPath, diff: fileDiff)
  }
}

@available(OSX 10.15, *)
private extension Scanner {
  func scanUpToPaths(resultPrefix: String = "") -> String? {
    let filePathsPrefix = "diff --git a/"
    let scanResult = compatibilityScanUpTo(filePathsPrefix)
    let result = resultPrefix + (scanResult ?? "")

    guard !isAtEnd else {
      return result
    }

    let potentialStartLocation = scanLocation
    let previousIndex = self.string.index(self.string.startIndex, offsetBy: scanLocation - 1)

    guard
      // Make sure "diff --git a/" is at a line start (not in the middle of a line).
      self.string[previousIndex] == "\n",
      let _ = try? scanPaths()
    else {
      scanLocation = potentialStartLocation + filePathsPrefix.count
      return scanUpToPaths(resultPrefix: result + filePathsPrefix)
    }

    // Set location to
    scanLocation = potentialStartLocation
    return result
  }

  func scanPaths() throws -> (oldPath: String, newPath: String) {
    // Expect string like:
    // `diff --git a/<oldPath> b/<newPath>`

    var scanLocation = self.scanLocation
    guard scanString("diff --git a/", into: nil) else {
      throw GitDiffCommandOutputParser.ParserError
        .diffStartNotFound(searchStartLocation: scanLocation)
    }

    scanLocation = self.scanLocation
    guard let oldPath = compatibilityScanUpTo(" b/") else {
      throw GitDiffCommandOutputParser.ParserError
        .oldFilePathNotFound(searchStartLocation: scanLocation)
    }

    // Skip to new path start
    scanLocation = self.scanLocation
    guard scanString(" b/", into: nil) else {
      throw GitDiffCommandOutputParser.ParserError
        .newFilePathNotFound(searchStartLocation: scanLocation)
    }

    scanLocation = self.scanLocation
    guard let newPath = compatibilityScanUpTo("\n") else {
      throw GitDiffCommandOutputParser.ParserError
        .newFilePathNotFound(searchStartLocation: scanLocation)
    }

    return (oldPath, newPath)
  }

  func scanChunkDiffLines() -> [FileDiff.Line]? {
    guard let _ = scanUpToChunkSeparator(), let _ = scanChunkSeparator() else {
      return nil
    }

    let diffLines = scanUpToChunkSeparator() ?? ""
    return FileDiff.Line.lines(diffContent: diffLines)
  }

  func scanUpToChunkSeparator(resultPrefix: String = "") -> String? {
    // "@@ -<1st_removed_line>,<number_of_removed_lines> +<1st_added_line>,<number_of_added_lines>"
    // e.g. "@@ -1,5 +1,5 @@"

    let chunkSeparatorPrefix = "@@ -"
    let result = resultPrefix + (compatibilityScanUpTo(chunkSeparatorPrefix) ?? "")

    guard !isAtEnd else {
      return result
    }

    let potentialStartLocation = scanLocation

    guard let _ = scanChunkSeparator() else {
      scanLocation = potentialStartLocation + chunkSeparatorPrefix.count
      return scanUpToChunkSeparator(resultPrefix: result + chunkSeparatorPrefix)
    }

    // Set location to
    scanLocation = potentialStartLocation
    return result
  }

  func scanChunkSeparator()
    -> (removed: CountableClosedRange<Int>, added: CountableClosedRange<Int>)? {

      guard let _ = compatibilityScanString("@@ -") else { return nil }
      guard let firstRemovedLine = scanInt() else { return nil }
      guard let _ = compatibilityScanString(",") else { return nil }
      guard let removedLineCount = scanInt() else { return nil }
      guard let _ = compatibilityScanString(" +") else { return nil }
      guard let firstAddedLine = scanInt() else { return nil }
      guard let _ = compatibilityScanString(",") else { return nil }
      guard let addedLineCount = scanInt() else { return nil }
      guard let _ = scanUpToCharacters(from: .newlines) else { return nil }
      guard let _ = scanCharacters(from: .newlines) else { return nil }

      return (firstRemovedLine ... firstRemovedLine + removedLineCount,
              firstAddedLine ... firstAddedLine + addedLineCount)
  }

  func compatibilityScanUpTo(_ substring: String) -> String? {
    if #available(OSX 10.15, *) {
      return scanUpToString(substring)
    } else {
      var resultNSString: NSString?
      guard scanUpTo(substring, into: &resultNSString) else {
        return nil
      }

      guard let unwrappedResult = resultNSString else {
        return nil
      }

      return String(unwrappedResult)
    }
  }

  func compatibilityScanString(_ searchString: String) -> String? {
    if #available(OSX 10.15, *) {
      return scanString(searchString)
    } else {
      var resultNSString: NSString?
      guard scanString(searchString, into: &resultNSString) else {
        return nil
      }

      guard let unwrappedResult = resultNSString else {
        return nil
      }

      return String(unwrappedResult)
    }
  }
}

extension GitDiffCommandOutputParser {
  enum ParserError: Error {
    case diffStartNotFound(searchStartLocation: Int)
    case oldFilePathNotFound(searchStartLocation: Int)
    case newFilePathNotFound(searchStartLocation: Int)
    case chunkHeaderNotFound
    case unsupportedOSVersion
  }
}

extension FileDiff.Line {
  static func lines(diffContent: String, skipUnmodified: Bool = true) -> [FileDiff.Line] {
    // Expected string:
    //
    // /// xcodebuild, etc). Intentionally empty, this enum is used as a namespace.
    // -internal enum Shell {}
    // +public enum Shell {}
    //
    //  extension Shell {

    return diffContent.split(separator: "\n").compactMap { line in
      if line.hasPrefix("+") {
        return FileDiff.Line(type: .added, content: String(line.suffix(line.count - 1)))
      } else if line.hasPrefix("-") {
        return FileDiff.Line(type: .removed, content: String(line.suffix(line.count - 1)))
      } else if line.hasPrefix(" ") {
        return skipUnmodified ? nil : FileDiff
          .Line(type: .unmodified, content: String(line.suffix(line.count - 1)))
      } else {
        // Actually should never go here.
        return nil
      }
    }
  }
}
