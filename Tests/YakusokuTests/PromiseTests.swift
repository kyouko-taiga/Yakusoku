import XCTest
@testable import Yakusoku

final class PromiseTests: XCTestCase {

  func testInitResolving() {
    let exp = expectation(description: "will resolve immediately")
    Promise(resolving: 0)
      .then  { _ in exp.fulfill() }
      .catch { _ in XCTFail() }
    wait(for: [exp], timeout: 0.0)
  }

  func testInitRejecting() {
    let exp = expectation(description: "will reject immediately")
    Promise(rejectingWith: ValueError("Fail!"))
      .then  { _ in XCTFail() }
      .catch { _ in exp.fulfill() }
    wait(for: [exp], timeout: 0.0)
  }

  func testSynchronousClosure() {
    let resolveExp = expectation(description: "will resolve synchronously")
    Promise { resolve, _ in resolve(0) }
      .then  { _ in resolveExp.fulfill() }
      .catch { _ in XCTFail() }
    wait(for: [resolveExp], timeout: 0.0)

    let rejectExp = expectation(description: "will reject synchronously")
    Promise { _, reject in reject(ValueError("Fail!")) }
      .then  { _ in XCTFail() }
      .catch { _ in rejectExp.fulfill() }
    wait(for: [rejectExp], timeout: 0.0)

    let throwExp = expectation(description: "will reject synchronously")
    Promise { _, _ in throw ValueError("Fail!") }
      .then  { _ in XCTFail() }
      .catch { _ in throwExp.fulfill() }
    wait(for: [throwExp], timeout: 0.0)
  }

  func testAsynchronousClosure() {
    let resolveExp = expectation(description: "will resolve asynchronously")
    Promise { resolve, _ in produce(0, after: .milliseconds(100), then: resolve) }
      .then  { _ in resolveExp.fulfill() }
      .catch { _ in XCTFail() }
    wait(for: [resolveExp], timeout: 0.2)

    let rejectExp = expectation(description: "will reject asynchronously")
    Promise { _, reject in fail(after: .milliseconds(100), then: reject) }
      .then  { _ in XCTFail() }
      .catch { _ in rejectExp.fulfill() }
    wait(for: [rejectExp], timeout: 0.2)
  }

  func testMultipleHandlers() {
    let resolveExp = expectation(description: "will resolve")
    resolveExp.expectedFulfillmentCount = 3

    let p0 = Promise { resolve, _ in produce(0, after: .milliseconds(100), then: resolve) }
    p0.then { _ in resolveExp.fulfill() }
    p0.then { _ in resolveExp.fulfill() }
    p0.then { _ in resolveExp.fulfill() }
    wait(for: [resolveExp], timeout: 0.2)

    let rejectExp = expectation(description: "will reject")
    rejectExp.expectedFulfillmentCount = 3

    let p1 = Promise<Int> { _, reject in fail(after: .milliseconds(100), then: reject) }
    p1.catch { _ in rejectExp.fulfill() }
    p1.catch { _ in rejectExp.fulfill() }
    p1.catch { _ in rejectExp.fulfill() }
    wait(for: [rejectExp], timeout: 0.2)
  }

  func testChainHandlers() {
    let exp0 = expectation(description: "will resolve")
    let inc: (Int) -> Int = { $0 + 1 }
    Promise { resolve, _ in produce(0, after: .milliseconds(100), then: resolve) }
      .then(inc)
      .then(inc)
      .then { x in
        XCTAssertEqual(x, 2)
        exp0.fulfill()
      }
    wait(for: [exp0], timeout: 0.2)

    let exp1 = expectation(description: "will resolve")
    Promise { resolve, _ in produce(0, after: .milliseconds(100), then: resolve) }
      .then { x in Promise { resolve, _ in resolve(x + 1) } }
      .then { x in
        XCTAssertEqual(x, 1)
        exp1.fulfill()
      }
    wait(for: [exp1], timeout: 0.2)

    let exp2 = expectation(description: "will resolve")
    Promise { resolve, _ in produce(0, after: .milliseconds(100), then: resolve) }
      .then { x in
        Promise { resolve, _ in self.produce(x + 1, after: .milliseconds(100), then: resolve) }
      }
      .then { x in
        XCTAssertEqual(x, 1)
        exp2.fulfill()
      }
    wait(for: [exp2], timeout: 0.3)
  }

  func testCatchException() {
    let exp0 = expectation(description: "will catch rejection")
    Promise<Int> { _, _ in throw ValueError("Fail!") }
      .then  { _ in XCTFail() }
      .catch { _ in exp0.fulfill() }
    wait(for: [exp0], timeout: 0.2)

    let exp1 = expectation(description: "will catch rejection")
    Promise { resolve, _ in produce(0, after: .milliseconds(100), then: resolve) }
      .then  { _ in throw ValueError("Fail!") }
      .then  { _ in XCTFail() }
      .catch { _ in exp1.fulfill() }
    wait(for: [exp1], timeout: 0.2)
  }

  func testRecover() {
    let exp0 = expectation(description: "will catch rejection")
    Promise<Int> { _, _ in throw ValueError("Fail!") }
      .catch { _ in 42 }
      .then  { n in
        XCTAssertEqual(n, 42)
        exp0.fulfill()
      }
    wait(for: [exp0], timeout: 0.2)

    let exp1 = expectation(description: "will catch rejection")
    Promise<Int> { _, _ in throw ValueError("Fail!") }
      .catch { _ in Promise { resolve, _ in resolve(42) }  }
      .then  { n in
        XCTAssertEqual(n, 42)
        exp1.fulfill()
      }
    wait(for: [exp1], timeout: 0.2)

    let exp2 = expectation(description: "will catch rejection")
    Promise<Int> { _, _ in throw ValueError("Fail!") }
      .catch { _ in
        Promise { resolve, _ in self.produce(42, after: .milliseconds(100), then: resolve) }
      }
      .then  { n in
        XCTAssertEqual(n, 42)
        exp2.fulfill()
      }
    wait(for: [exp2], timeout: 0.3)
  }

  func testFinally() {
    let exp0 = expectation(description: "will execute finally")
    Promise(resolving: 0)
      .finally { exp0.fulfill() }
    wait(for: [exp0], timeout: 0.0)

    let exp1 = expectation(description: "will execute finally")
    Promise<Int>(rejectingWith: ValueError("Fail!"))
      .finally { exp1.fulfill() }
    wait(for: [exp1], timeout: 0.0)

    let exp2 = expectation(description: "will chain after finally")
    Promise(resolving: 0)
      .finally { 42 }
      .then    { n in
        XCTAssertEqual(n, 42)
        exp2.fulfill()
      }
    wait(for: [exp2], timeout: 0.0)

    let exp3 = expectation(description: "will chain after asynchronous finally")
    Promise<Int>(rejectingWith: ValueError("Fail!"))
      .finally { 42 }
      .then    { n in
        XCTAssertEqual(n, 42)
        exp3.fulfill()
      }
    wait(for: [exp3], timeout: 0.0)

    let exp4 = expectation(description: "will chain after asynchronous finally")
    Promise(resolving: 0)
      .finally {
        Promise { resolve, _ in self.produce(42, after: .milliseconds(100), then: resolve) }
      }
      .then { n in
        XCTAssertEqual(n, 42)
        exp4.fulfill()
      }
    wait(for: [exp4], timeout: 0.2)

    let exp5 = expectation(description: "will chain after asynchronous finally")
    Promise<Int>(rejectingWith: ValueError("Fail!"))
      .finally {
        Promise { resolve, _ in self.produce(42, after: .milliseconds(100), then: resolve) }
      }
      .then { n in
        XCTAssertEqual(n, 42)
        exp5.fulfill()
      }
    wait(for: [exp5], timeout: 0.2)
  }

  func testInvalidHandler() {
    let exp0 = expectation(description: "will reject")
    let promise0 = Promise(resolving: 42)
    promise0
      .then  { _ in promise0 }
      .catch { (e) -> Void in
        XCTAssert((e as? PromiseError) == .invalidHandler)
        exp0.fulfill()
      }
    wait(for: [exp0], timeout: 0.0)

    let exp1 = expectation(description: "will reject")
    let promise1 = Promise<Int>(rejectingWith: ValueError("Fail!"))
    promise1
      .catch { _ in promise1 }
      .catch { (e) -> Void in
        XCTAssert((e as? PromiseError) == .invalidHandler)
        exp1.fulfill()
      }
    wait(for: [exp1], timeout: 0.0)

    let exp2 = expectation(description: "will reject")
    let promise2 = Promise(resolving: 42)
    promise2
      .finally { promise2 }
      .catch   { (e) -> Void in
        XCTAssert((e as? PromiseError) == .invalidHandler)
        exp2.fulfill()
      }
    wait(for: [exp2], timeout: 0.0)

    let exp3 = expectation(description: "will reject")
    let promise3 = Promise<Int>(rejectingWith: ValueError("Fail!"))
    promise3
      .finally { promise3 }
      .catch   { (e) -> Void in
        XCTAssert((e as? PromiseError) == .invalidHandler)
        exp3.fulfill()
      }
    wait(for: [exp3], timeout: 0.0)
  }

  func testAll() {
    let exp0 = expectation(description: "will fulfill")
    Promise<[Int]>.all([])
      .then { results in
        XCTAssert(results.isEmpty)
        exp0.fulfill()
    }
    wait(for: [exp0], timeout: 0.0)

    let exp1 = expectation(description: "will fulfill")
    Promise.all([Promise(resolving: "foo"),  Promise(resolving: "bar")])
      .then { results in
        XCTAssertEqual(results[0], "foo")
        XCTAssertEqual(results[1], "bar")
        exp1.fulfill()
      }
    wait(for: [exp1], timeout: 0.0)

    let exp2 = expectation(description: "will reject")
    Promise.all([Promise(resolving: "foo"), Promise(rejectingWith: ValueError("Fail!"))])
      .catch { _ in exp2.fulfill() }
    wait(for: [exp2], timeout: 0.0)
  }

  private func produce(
    _ value: Int, after delta: DispatchTimeInterval, then resolve: @escaping Promise<Int>.Resolve)
  {
    DispatchQueue.main.asyncAfter(deadline: .now() + delta) { resolve(value) }
  }

  private func fail(after delta: DispatchTimeInterval, then reject: @escaping Promise<Int>.Reject) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delta) { reject(ValueError("Fail!")) }
  }

  static var allTests = [
    ("testInitResolving", testInitResolving),
    ("testInitRejecting", testInitRejecting),
    ("testSynchronousClosure", testSynchronousClosure),
    ("testAsynchronousClosure", testAsynchronousClosure),
    ("testMultipleHandlers", testMultipleHandlers),
    ("testChainHandlers", testChainHandlers),
    ("testCatchException", testCatchException),
    ("testRecover", testRecover),
    ("testFinally", testFinally),
    ("testInvalidHandler", testInvalidHandler),
    ("testAll", testAll),
  ]

}

private struct ValueError<T>: Error {

  init(_ value: T) {
    self.value = value
  }

  let value: T

}
