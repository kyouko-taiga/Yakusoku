import XCTest

import YakusokuTests

var tests = [XCTestCaseEntry]()
tests += PromiseTests.allTests()
XCTMain(tests)
