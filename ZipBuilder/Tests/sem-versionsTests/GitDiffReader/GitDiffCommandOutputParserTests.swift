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

import XCTest
import Foundation
@testable import sem_versions

final class GitDiffCommandOutputParserTests: XCTestCase {
  func testSingleFileDiff() {
    do {
      let diffString =
        try String(contentsOfFile: "/Users/mmaksym/Projects/firebase-ios-sdk2/ZipBuilder/TestResources/GitDiffReader/TestFileDiff.diff")

      let parser = GitDiffCommandOutputParser(string: diffString)

      let diff = try parser.parseDiff()
      XCTAssertEqual(diff.files.count, 1)

      guard let file = diff.files.first else {
        XCTFail("Missing modified file diff.")
        return
      }

      XCTAssertEqual(file.diff.oldPath, "ZipBuilder/Sources/ZipBuilder/ShellUtils.swift")
      XCTAssertEqual(file.diff.newPath, "ZipBuilder/Sources/ShellUtils/ShellUtils.swift")

      XCTAssertEqual(file.diff.lines.count, 17)
    } catch {
      XCTFail("Parse Error: \(error)")
    }
  }

  func testMultiFileDiff() {
    do {
      let diffString =
        try String(contentsOfFile: "/Users/mmaksym/Projects/firebase-ios-sdk2/ZipBuilder/TestResources/GitDiffReader/MultiFileDiff.diff")

      let parser = GitDiffCommandOutputParser(string: diffString)

      let diff = try parser.parseDiff()

      XCTAssertEqual(diff.files.count, 11)

      //        XCTAssertEqual(fileDiff.oldPath, "ZipBuilder/Sources/ZipBuilder/ShellUtils.swift")
      //        XCTAssertEqual(fileDiff.newPath, "ZipBuilder/Sources/ShellUtils/ShellUtils.swift")
      //
      //        XCTAssertEqual(fileDiff.lines.count, 17)
    } catch {
      XCTFail("Parse Error: \(error)")
    }
  }
}
