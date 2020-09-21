import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ReleaseManifestUpdaterTests.allTests),
    ]
}
#endif
