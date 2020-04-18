import UIKit
import Promise

class ViewController: UIViewController {

    enum GenericError: Error {
        case random
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        let promise = Promise<String>()
            .always {
                print("Always called")
        }

        promise.cancellationHandler = self

        let secondPromise = promise.then({ string -> Bool in
            throw GenericError.random
            print(string)
            return true
        })

        let thirdPromise = secondPromise.then({
            return $0 ? "Hell yes" : "Hell nah"
        })

        thirdPromise.then({
            print($0)
        })
        thirdPromise.cancel()


        promise.resolve(value: "Initial value")
//        promise.reject(error: GenericError.random)

        promise.catch({ _ in
            print("First promise catch")
        })

        secondPromise.catch({ _ in
            print("Second promise catch")
        })

        thirdPromise.catch({ _ in
            print("Third promise catch")
        })


        let exampleJson =

"""
{
    "value": "Some string"
}
""".data(using: .utf8)!

        Promise { fulfill, reject in
            do {
                let object = try JSONDecoder().decode(SomeDecodable.self, from: exampleJson)
                fulfill(object.value)
            } catch {
                reject(error)
            }
        }
        .then({ print($0) })
        .catch({ print($0.localizedDescription) })
        .always {
            print("Called always on standalone function")
        }
    }
}

extension ViewController: PromiseCancellationHandler {

    func cancel() {
        print("Cancel called")
    }
}

struct SomeDecodable: Decodable {
    let value: String
}
