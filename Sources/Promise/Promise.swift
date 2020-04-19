/*
Copyright © 2020 Rouk OÜ. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

/// A construct that an object needs to implement if it wants to listen to a cancellation from a promise.
public protocol PromiseCancellationHandler: AnyObject {
    
    /// Method that will be called if a promise is cancelled.
    func cancel()
}

/// A construct for supporting asynchronous tasks. This construct does not handle any threading itself. This must be handled by the callers and consumers.
public final class Promise<T> {
    
    /// A typealias for cancel callback.
    public typealias CancelCallback = () -> Void

    /// A construct representing the state of the promise.
    public enum State<T> {
        
        /// A pending state of the promise. If a promise has this state then it has not been resolved yet and has not called any callbacks.
        case pending
        
        /// A resolved state of the promise. If a promise has this state then it has been resolved and has called the appropriate callbacks to the result.
        case resolved(Result<T, Error>)
    }

    /// A cancellation handler object. If an object needs to listen to the cancellation of a promise then it should be assigned to this variable.
    public weak var cancellationHandler: PromiseCancellationHandler?
    
    /// A callback which is called if the promise is cancelled.
    public var cancelCallback: CancelCallback?
    
    /// The promise's state.
    public private(set) var state: State<T> = .pending

    private var onSuccessCallbacks = [(T) -> Void]()
    private var onErrorCallbacks = [(Error) -> Void]()

    /// A init that can be used a pending promise.
    public init() {
        self.state = .pending
    }

    /// A init that can be used to create a promise with a resolved state.
    /// - Parameter value: The resolved value of the state.
    public init(value: T) {
        self.state = .resolved(.success(value))
    }

    /// A init that can be used to create a promise with a resolved state.
    /// - Parameter error: The resolved error of the state.
    public init(error: Error) {
        self.state = .resolved(.failure(error))
    }

    /// A init that can be used to create a pending promise.
    /// - Parameter resolver: A resolver that resolves the promise.
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

    /// A method to add a block of code to be executed when a promise is completed.
    /// - Parameter onFulfill: A block of code that gets called when a promise is resolved with a `.success(T)` result. This block of code returns  a new Promise.
    /// - Returns: A new promise of type `Promise<U>` where `U` is dependant on the execution block.
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

    /// A method to add a block of code to be executed when a promise is completed.
    /// - Parameter onFulfill: A block of code that gets called when a promise is resolved with a `.success(T)` result.
    /// - Returns: A new promise of type `Promise<U>` where `U` is dependant on the execution block.
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

    /// A method to add a block of code to be executed when a promise is resolved with a failed state.
    /// - Parameter onReject: A block of code that gets called when a promise is resolved with a `.failure(Error)` result. This block of code returns  a new Promise.
    /// - Returns: The the promise this method was called on.
    @discardableResult
    public func `catch`(_ onReject: @escaping (Error) -> Void) -> Self {
        onErrorCallbacks.append(onReject)
        resolveCallbacksIfNecessary()
        return self
    }

    /// A method used to resolve a promise with a value.
    /// This method expects the promise not to be resolved already.
    /// - Parameter value: The value that the promise is resolved with.
    public func resolve(value: T) {
        if case .resolved = state {
            assertionFailure("Promise already resolved")
        }

        self.state = .resolved(.success(value))
        resolveCallbacksIfNecessary()
    }

    /// A method used to resolve a promise with an error.
    /// This method expects the promise not to be resolved already.
    /// - Parameter error: The error that the promise is resolved with.
    public func reject(error: Error) {
        if case .resolved = state {
            assertionFailure("Promise already resolved")
        }

        self.state = .resolved(.failure(error))
        resolveCallbacksIfNecessary()
    }

    /// A method to add a block of code to be executed when a promise is resolved with any state.
    /// - Parameter callback: A block of code that gets called when a promise is resolved with any state.
    /// - Returns: The the promise this method was called on.
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

    /// A method that can be called to cancel a promise.
    public func cancel() {
        cancellationHandler?.cancel()
        cancelCallback?()
        clearCallbacks()
    }
}

extension Collection {
    
    /// A function that can be used to flatten an array of promises of type `T`
    /// - Returns: A promise with type `Promise<[T]>`.
    public func flatten<T>() -> Promise<[T]> where Element == Promise<T> {
         let flattenedPromise = Promise<[T]>()

         var elements = [T]()
         elements.reserveCapacity(self.count)

         var iterator = makeIterator()

         func handle(_ promise: Promise<T>) {
            if case let .resolved(result) = promise.state {
                 switch result {
                 case .success(value: let value):
                     elements.append(value)
                     if let next = iterator.next() {
                         handle(next)
                     } else {
                        flattenedPromise.resolve(value: elements)
                     }

                 case .failure(error: let error):
                    flattenedPromise.reject(error: error)
                 }
                 return
             }

             promise.then({ value in
                 elements.append(value)
                 if let next = iterator.next() {
                     handle(next)
                 } else {
                    flattenedPromise.resolve(value: elements)
                 }
             }).catch({ error in
                flattenedPromise.reject(error: error)
             })
         }

         if let first = iterator.next() {
             handle(first)
         } else {
            flattenedPromise.resolve(value: elements)
         }

         return flattenedPromise
     }
}
