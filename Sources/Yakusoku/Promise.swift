public final class Promise<Value> {

  public typealias Resolve = (Value) -> Void
  public typealias Reject = (Error) -> Void

  public init(_ resolver: (@escaping Resolve, @escaping Reject) throws -> Void) {
    do {
      try resolver(resolve, reject)
    } catch {
      self.error = error
    }
  }

  public init(resolving value: Value) {
    self.value = value
  }

  public init(rejectingWith error: Error) {
    self.error = error
  }

  /// The value of the promise, if and once fulfilled.
  private var value: Value?
  /// The rejection error of the promise, if and once rejected.
  private var error: Error?
  /// The fulfillment and rejection callbacks of the promise.
  private var callbacks: [Callback<Value>] = []

  /// Whether the promise has been fulfilled.
  public var isFulfilled: Bool { return value != nil }
  /// Whether the promise has been rejected.
  public var isRejected: Bool { return error != nil }
  /// Whether the promise is till pending.
  public var isPending: Bool { return value == nil && error == nil }

  @discardableResult
  public func then<Next>(_ handler: @escaping (Value) throws -> Promise<Next>) -> Promise<Next> {
    return Promise<Next> { resolve, reject in
      add(callback: Callback(
        onFulfill: { value in
          do {
            let promise = try handler(value)
            guard (promise as? Promise<Value>) !== self else {
              reject(PromiseError.invalidHandler)
              return
            }
            promise.then(resolve).catch(reject)
          } catch let error {
            reject(error)
          }
        },
        onReject: reject))
    }
  }

  @discardableResult
  public func then<Next>(_ handler: @escaping (Value) throws -> Next) -> Promise<Next> {
    return Promise<Next> { resolve, reject in
      add(callback: Callback(
        onFulfill: { value in
          do {
            try resolve(handler(value))
          } catch let error {
            reject(error)
          }
        },
        onReject: reject))
    }
  }

  @discardableResult
  public func then(_ handler: @escaping (Value) -> Void) -> Promise {
    add(callback: Callback(onFulfill: handler, onReject: { _ in }))
    return self
  }

  @discardableResult
  public func `catch`(_ handler: @escaping (Error) throws -> Promise) -> Promise {
    return Promise<Value> { resolve, reject in
      add(callback: Callback(
        onFulfill: resolve,
        onReject: { error in
          do {
            let promise = try handler(error)
            guard promise !== self else {
              reject(PromiseError.invalidHandler)
              return
            }
            promise.then(resolve).catch(reject)
          } catch let error {
            reject(error)
          }
        }))
    }
  }

  @discardableResult
  public func `catch`(_ handler: @escaping (Error) throws -> Value) -> Promise {
    return Promise<Value> { resolve, reject in
      add(callback: Callback(
        onFulfill: resolve,
        onReject: { error in
          do {
            try resolve(handler(error))
          } catch let error {
            reject(error)
          }
        }))
    }
  }

  @discardableResult
  public func `catch`(_ handler: @escaping (Error) -> Void) -> Promise {
    add(callback: Callback(onFulfill: { _ in }, onReject: handler))
    return self
  }

  @discardableResult
  public func finally<Next>(_ handler: @escaping () throws -> Promise<Next>) -> Promise<Next> {
    return Promise<Next> { resolve, reject in
      add(callback: Callback(
        onFulfill: { _ in
          do {
            let promise = try handler()
            guard promise !== self else {
              reject(PromiseError.invalidHandler)
              return
            }
            promise.then(resolve).catch(reject)
          } catch let error {
            reject(error)
          }
        },
        onReject: { _ in
          do {
            let promise = try handler()
            guard promise !== self else {
              reject(PromiseError.invalidHandler)
              return
            }
            promise.then(resolve).catch(reject)
          } catch let error {
            reject(error)
          }
        }
      ))
    }
  }

  @discardableResult
  public func finally<Next>(_ handler: @escaping () throws -> Next) -> Promise<Next> {
    return Promise<Next> { resolve, reject in
      add(callback: Callback(
        onFulfill: { _ in
          do {
            try resolve(handler())
          } catch let error {
            reject(error)
          }
        },
        onReject: { _ in
          do {
            try resolve(handler())
          } catch let error {
            reject(error)
          }
        }
      ))
    }
  }

  @discardableResult
  public func finally(_ handler: @escaping () -> Void) -> Promise {
    add(callback: Callback(
      onFulfill: { _ in handler() },
      onReject : { _ in handler() }))
    return self
  }

  @discardableResult
  public static func all<S>(_ promises: S) -> Promise<[Value]>
    where S: Sequence, S.Element == Promise<Value>
  {
    let array = Array(promises)
    guard !array.isEmpty
      else { return Promise<[Value]>(resolving: []) }

    return Promise<[Value]> { resolve, reject in
      var results: [Value?] = Array(repeating: nil, count: array.count)
      var pending = array.count

      for (i, promise) in array.enumerated() {
        promise
          .then { result in
            pending -= 1
            results[i] = result
            if pending == 0 {
              resolve(results.map({ $0! }))
            }
          }
          .catch(reject)
      }
    }
  }

  private func resolve(value: Value) {
    guard isPending else { return }
    self.value = value
    fireCallbacks()
  }

  private func reject(error: Error) {
    guard isPending else { return }
    self.error = error
    fireCallbacks()
  }

  private func add(callback: Callback<Value>) {
    callbacks.append(callback)
    fireCallbacks()
  }

  private func fireCallbacks() {
    guard !isPending else { return }

    while let callback = callbacks.popLast() {
      if isFulfilled {
        callback.onFulfill(value!)
      } else if isRejected {
        callback.onReject(error!)
      }
    }
  }

}

private struct Callback<Value> {

  let onFulfill: (Value) -> Void
  let onReject: (Error) -> Void

}

public enum PromiseError: Error {

  case invalidHandler

}
