import Foundation

public protocol PromiseCancellationHandler: AnyObject {
    func cancel()
}

public final class Promise<T> {

    public enum State<T> {
        case pending
        case resolved(Result<T, Error>)
    }

    public weak var cancellationHandler: PromiseCancellationHandler?
    public var state: State<T> = .pending

    private var onSuccessCallbacks = [(T) -> Void]()
    private var onErrorCallbacks = [(Error) -> Void]()

    public init() {
        self.state = .pending
    }

    public init(value: T) {
        self.state = .resolved(.success(value))
    }

    public init(error: Error) {
        self.state = .resolved(.failure(error))
    }

    public init(
        _ resolver: @escaping (
        _ onFulfill: @escaping (T) -> Void,
        _ onReject: @escaping (Error) -> Void) throws -> Void
    ) {
        do {
            try resolver(resolve, reject)
        } catch {
            reject(error: error)
        }
    }

    @discardableResult
    public func then<U>(_ onFullfill: @escaping (T) throws -> Promise<U>) -> Promise<U> {
        let newPromise = Promise<U>()
        newPromise.cancellationHandler = self

        onSuccessCallbacks.append({ value in
            do {
                let promise = try onFullfill(value)
                promise.onSuccessCallbacks.append(newPromise.resolve)
                promise.onErrorCallbacks.append(newPromise.reject)
                promise.resolveCallbacksIfNecessary()
            } catch {
                newPromise.reject(error: error)
            }
        })

        onErrorCallbacks.append(newPromise.reject)
        resolveCallbacksIfNecessary()

        return newPromise
    }

    @discardableResult
    public func then<U>(_ onFullfill: @escaping (T) throws -> U) -> Promise<U> {
        return then({ value in
            do {
                return Promise<U>(value: try onFullfill(value))
            } catch {
                throw error
            }
        })
    }

    @discardableResult
    public func `catch`(_ onReject: @escaping (Error) -> Void) -> Self {
        onErrorCallbacks.append(onReject)
        resolveCallbacksIfNecessary()
        return self
    }

    public func resolve(value: T) {
        if case .resolved = state {
            assertionFailure("Promise already resolved")
        }

        self.state = .resolved(.success(value))
        resolveCallbacksIfNecessary()
    }

    public func reject(error: Error) {
        if case .resolved = state {
            assertionFailure("Promise already resolved")
        }

        self.state = .resolved(.failure(error))
        resolveCallbacksIfNecessary()
    }

    @discardableResult
    public func always(_ callback: @escaping () -> Void) -> Self {
        onSuccessCallbacks.append({ _ in callback() })
        onErrorCallbacks.append({ _ in callback() })
        resolveCallbacksIfNecessary()
        return self
    }

    private func resolveCallbacksIfNecessary() {
        if case let .resolved(result) = state {
            switch result {

            case .success(let value):
                onSuccessCallbacks.forEach({ callback in callback(value) })

            case .failure(let error):
                onErrorCallbacks.forEach({ callback in callback(error) })
            }

            clearCallbacks()
        }
    }

    private func clearCallbacks() {
        onSuccessCallbacks.removeAll()
        onErrorCallbacks.removeAll()
    }
}

extension Promise: PromiseCancellationHandler {

    public func cancel() {
        cancellationHandler?.cancel()
        clearCallbacks()
    }
}
