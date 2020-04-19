import XCTest
@testable import Promise

final class PromiseTests: XCTestCase {

    static var allTests = [
        ("testInit_createsPendingState", testInit_createsPendingState),
        ("testInit_createsResolvedState", testInit_createsResolvedState),
        ("testInit_createsRejectedState", testInit_createsRejectedState),
        ("testInitWithBlock_createsPendingState", testInitWithBlock_createsPendingState),
        ("testInitWithBlock_resolvesState", testInitWithBlock_resolvesState),
        ("testInitWithBlock_resolvesStateWithFailure", testInitWithBlock_resolvesStateWithFailure),
        ("testThenBlock_notCalledIfPromisePending", testThenBlock_notCalledIfPromisePending),
        ("testThenBlock_calledWhenFirstPromiseIsAlreadyResolved", testThenBlock_calledWhenFirstPromiseIsAlreadyResolved),
        ("testThenBlock_calledWhenPromiseResolvesLater", testThenBlock_calledWhenPromiseResolvesLater),
        ("testThenBlock_calledWhenPromiseResolvedAfterThenBlockAdded", testThenBlock_calledWhenPromiseResolvedAfterThenBlockAdded),
        ("testCatchBlock_notCalledIfPromiseIsPending", testCatchBlock_notCalledIfPromiseIsPending),
        ("testCatchBlock_isCalledIfPromiseFails", testCatchBlock_isCalledIfPromiseFails),
        ("testCatchBlock_isCalledIfChainedToThenBlock", testCatchBlock_isCalledIfChainedToThenBlock),
        ("testAlwaysBlock_isNotCalledIfPromiseIsPending", testAlwaysBlock_isNotCalledIfPromiseIsPending),
        ("testAlwaysBlock_isCalledOnSucceededPromise", testAlwaysBlock_isCalledOnSucceededPromise),
        ("testAlwaysBlock_isCalledOnFailedPromise", testAlwaysBlock_isCalledOnFailedPromise),
        ("testAlwaysBlock_succeeedsIfChainedToThen", testAlwaysBlock_succeeedsIfChainedToThen),
        ("testAlwaysBlock_succeeedsIfChainedToCatch", testAlwaysBlock_succeeedsIfChainedToCatch),
        ("testAlwaysBlock_succeeedsIfChainedToMultipleBlocks", testAlwaysBlock_succeeedsIfChainedToMultipleBlocks),
        ("testCancel_clearsCallbacks", testCancel_clearsCallbacks),
        ("testCancel_clearsCallbacksUpstream", testCancel_clearsCallbacksUpstream),
        ("testCancellationReference", testCancellationReference),
        ("testFlattenResolvesOnEmptyArray", testFlattenResolvesOnEmptyArray),
        ("testFlattenRemainsPendingIfInputPending", testFlattenRemainsPendingIfInputPending),
        ("testFlattenResolvesIfAllInputsResolve", testFlattenResolvesIfAllInputsResolve),
        ("testFlattenRejectsIfOneInInputRejects", testFlattenRejectsIfOneInInputRejects),
        ("testFlattenRetainsValues", testFlattenRetainsValues)        
    ]

    func testInit_createsPendingState() {
        let promise = Promise<Void>()

        if case .resolved = promise.state {
            XCTFail("Promise state should be pending.")
        }
    }

    func testInit_createsResolvedState() {
        let valueString = "Some Value"
        let promise = Promise(value: valueString)

        if case let .resolved(value) = promise.state {
            switch value {
            case .success(let string):
                XCTAssertEqual(string, valueString)

            case .failure:
                XCTFail("Promise should have success result.")
            }
        } else {
            XCTFail("Promise should be resolved.")
        }
    }

    func testInit_createsRejectedState() {
        let promise = Promise<Void>(error: TestError.error)

        if case let .resolved(value) = promise.state {
            switch value {
            case .success:
                XCTFail("Promise should have failure result.")

            case .failure(let error):
                if let resultError = error as? TestError {
                    XCTAssertEqual(resultError, TestError.error)
                } else {
                    XCTFail("Encountered error of wrong type.")
                }
            }
        } else {
            XCTFail("Promise should be resolved.")
        }
    }

    func testInitWithBlock_createsPendingState() {
        let promise = Promise<Void> { _, _ in }
        if case .resolved = promise.state {
            XCTFail("Promise state should be pending.")
        }
    }

    func testInitWithBlock_resolvesState() {
        let valueString = "Some Value"

        let promise = Promise { fulfill, _ in
            fulfill(valueString)
        }

        if case let .resolved(value) = promise.state {
            switch value {
            case .success(let string):
                XCTAssertEqual(string, valueString)

            case .failure:
                XCTFail("Promise should have success result.")
            }
        } else {
            XCTFail("Promise should be resolved.")
        }
    }

    func testInitWithBlock_resolvesStateWithFailure() {
        let promise = Promise<Void> { _, reject in
            reject(TestError.error)
        }

        if case let .resolved(value) = promise.state {
            switch value {
            case .success:
                XCTFail("Promise should have failure result.")

            case .failure(let error):
                if let resultError = error as? TestError {
                    XCTAssertEqual(resultError, TestError.error)
                } else {
                    XCTFail("Encountered error of wrong type.")
                }
            }
        } else {
            XCTFail("Promise should be resolved.")
        }
    }

    func testThenBlock_notCalledIfPromisePending() {
        let promise = Promise<Void>()
        promise.then({ XCTFail("Should not be called because promise should be pending.") })
    }

    func testThenBlock_calledWhenFirstPromiseIsAlreadyResolved() throws {
        let valueString = "Some Value"
        let promise = Promise(value: valueString)

        try await(for: promise.then({ value in XCTAssertEqual(value, valueString) }))
    }

    func testThenBlock_calledWhenPromiseResolvesLater() throws {
        let valueString = "Some Value"
        let promise = Promise<String>()

        promise.resolve(value: valueString)
        try await(for: promise.then({ value in XCTAssertEqual(value, valueString) }))
    }

    func testThenBlock_calledWhenPromiseResolvedAfterThenBlockAdded() {
        let valueString = "Some Value"
        let promise = Promise<String>()

        let expectation = self.expectation(description: "Waiting on promise")
        promise
            .then({ value in XCTAssertEqual(value, valueString) })
            .then({ expectation.fulfill() })

        promise.resolve(value: valueString)

        waitForExpectations(timeout: 1)
    }


    func testCatchBlock_notCalledIfPromiseIsPending() {
        let promise = Promise<Void>()
        promise.catch({ _ in XCTFail("Should not be called for a pending promise") })
    }

    func testCatchBlock_isCalledIfPromiseFails() throws {
        let promise = Promise<Void>(error: TestError.error)
        try await(for: promise.catch({ error in
            if let error = error as? TestError {
                XCTAssertEqual(error, TestError.error)
            } else {
                XCTFail("Caught an error of a wrong type.")
            }
        }))
    }

    func testCatchBlock_isCalledIfChainedToThenBlock() throws {
        let promise = Promise<Void>(error: TestError.error)

        try await(for:
            promise
                .then({ XCTFail("Should not be called because promise should fail.")})
                .catch({ error in
                    if let error = error as? TestError {
                        XCTAssertEqual(error, TestError.error)
                    } else {
                        XCTFail("Caught an error of a wrong type.")
                    }
                })
        )
    }

    func testAlwaysBlock_isNotCalledIfPromiseIsPending() {
        let promise = Promise<Void>()

        promise.always {
            XCTFail("Should not be called on a pending promise.")
        }
    }

    func testAlwaysBlock_isCalledOnSucceededPromise() {
        let promise = Promise<Void>(value: ())
        let expecation = self.expectation(description: "Waiting on always")

        promise.always {
            expecation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testAlwaysBlock_isCalledOnFailedPromise() {
        let promise = Promise<Void>(error: TestError.error)
        let expecation = self.expectation(description: "Waiting on always")

        promise.always {
            expecation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testAlwaysBlock_succeeedsIfChainedToThen() {
        let promise = Promise<Void>(error: TestError.error)
        let expecation = self.expectation(description: "Waiting on always")

        promise
            .then({ XCTFail("Should not be called.") })
            .always {
            expecation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testAlwaysBlock_succeeedsIfChainedToCatch() {
        let promise = Promise<Void>(value: ())
        let expecation = self.expectation(description: "Waiting on always")

        promise
            .catch({ _ in XCTFail("Should not be called.") })
            .always {
            expecation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testAlwaysBlock_succeeedsIfChainedToMultipleBlocks() {
        let promise = Promise<Void>(error: TestError.error)
        let expecation = self.expectation(description: "Waiting on always")

        promise
            .then({ XCTFail("Should not be called.") })
            .then({ XCTFail("Should not be called.") })
            .catch({ error in
                if let error = error as? TestError {
                    XCTAssertEqual(error, TestError.error)
                } else {
                    XCTFail("Caught an error of a wrong type.")
                }
            })
            .always {
                expecation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testCancel_clearsCallbacks() {
        let promise = Promise<Void>()
        let promise2 = Promise<Void>()

        promise.then({ XCTFail("Should not be called") })
        promise2.catch({ _ in XCTFail("Should not be called") })

        promise.cancel()
        promise2.cancel()

        promise.resolve(value: ())
        promise2.reject(error: TestError.error)
    }

    func testCancel_clearsCallbacksUpstream() {
        let promise = Promise<Void>()
        let promise2 = promise.then({ XCTFail("Should not be called") })

        promise2.then({ XCTFail("Should not be called") })
        promise2.cancel()

        promise.resolve(value: ())
    }

    func testCancellationReference() {
        let cancellationReference = CancellationHandlerStub()
        let promise = Promise<Void>()
        promise.cancellationHandler = cancellationReference
        XCTAssertEqual(cancellationReference.cancelCalled, 0)

        promise.then({ XCTFail("Should not be called") })
        promise.cancel()
        XCTAssertEqual(cancellationReference.cancelCalled, 1)

        promise.resolve(value: ())
    }
    
    func testFlattenResolvesOnEmptyArray() {
         let emptyArray: [Promise<Void>] = []
         let flattened = emptyArray.flatten()
        XCTAssertNoThrow(try await(for: flattened))
        if case .pending = flattened.state {
            XCTFail("Promise state should be resolved")
        }
     }

     func testFlattenRemainsPendingIfInputPending() {
         let arrayWithPending = [Promise<Void>()]
         let flattened = arrayWithPending.flatten()
        if case .resolved = flattened.state {
            XCTFail("Promise state should be pending")
        }
     }

     func testFlattenResolvesIfAllInputsResolve() {
         let void1 = Promise<Void>(value: ())
         let void2 = Promise<Void>(value: ())
         let void3 = Promise<Void>()
         let input = [void1, void2, void3]
         let flattened = input.flatten()

         if case .resolved = flattened.state {
             XCTFail("Promise state should be pending")
         }
        
        void3.resolve(value: ())
        XCTAssertNoThrow(try await(for: flattened))

         if case .pending = flattened.state {
             XCTFail("Promise state should be resolved")
         }
     }

     func testFlattenRejectsIfOneInInputRejects() {
         let void1 = Promise<Void>(value: ())
         let void2 = Promise<Void>(value: ())
         let void3 = Promise<Void>(value: ())
         let rejectedPromise = Promise<Void>(error: TestError.error)
         var input = [void1, void2, void3]

         var flattened = input.flatten()
        XCTAssertNoThrow(try await(for: flattened))
        if case .pending = flattened.state {
            XCTFail("Promise state should be resolved")
        }

         input.append(rejectedPromise)
         flattened = input.flatten()

        XCTAssertNoThrow(try await(for: flattened))
        if case let .resolved(value) = flattened.state {
            switch value {
            case .success:
                XCTFail("Promise should be rejected")
            case let .failure(error):
                if let error = error as? TestError {
                    XCTAssertEqual(error, TestError.error)
                } else {
                    XCTFail("Found error of wrong type.")
                }
            }
        } else {
            XCTFail("Promise state should be resolved")
        }
     }

     func testFlattenRetainsValues() {
         let promise1 = Promise(value: "Promise 1")
         let promise2 = Promise(value: "Promise 2")
         let promise3 = Promise(value: "Promise 3")
         let flattened = [promise1, promise2, promise3].flatten()

         let inputValues = ["Promise 1", "Promise 2", "Promise 3"]
         var flattenedValuesCount = 0
         let thenBlock = flattened
             .then({ values in
                 flattenedValuesCount = values.count
                 values.forEach({ XCTAssertTrue(inputValues.contains($0))})
             })

        XCTAssertNoThrow(try await(for: flattened))
        XCTAssertNoThrow(try await(for: thenBlock))
        if case .pending = flattened.state {
            XCTFail("Promise state should be resolved")
        }
         XCTAssertEqual(flattenedValuesCount, 3)
     }

    private func await<T>(for promise: Promise<T>) throws {
        let expectation = self.expectation(description: "Waiting on promise")
        promise.always ({
            expectation.fulfill()
        })

        var error: Error?
        waitForExpectations(timeout: 1) { expectationError in
            error = expectationError
        }

        if let error = error {
            throw error
        }
    }
}

enum TestError: Error {
    case error
}

class CancellationHandlerStub: PromiseCancellationHandler {

    private(set) var cancelCalled = 0

    func cancel() {
        cancelCalled += 1
    }
}
