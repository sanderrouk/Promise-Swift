# Promise
![Linux Build and Test](https://github.com/sanderrouk/Promise-iOS/workflows/Linux%20Build%20and%20Test/badge.svg)  ![MacOS Build and Test](https://github.com/sanderrouk/Promise-iOS/workflows/MacOS%20Build%20and%20Test/badge.svg)

Promise is a simple Swift framework that works with iOS, MacOS and Linux. Promise provides a simple way for synchronization. The purpose of this framework is to provide a simple lightweight implementation of Promises for Swift. If you are looking for a more robust implementation then we recommend [Google's Promises](https://github.com/google/promises) which are very robust and fairly light weight. This framework was built to be included in iOS PowerTools. A benefit this framework brings is that the entirety of the implementation is very lightweight and if desired can be added to a project without any dependency managers making the footprint smaller.

## Installation

### Using the Source Files
A very lightweight way to use this is to navigate to the `Sources` directory and add all of the files from there to your project. This however does come with a caveat that the code will not be updated automatically in case of new versions. For a dependency manager approach follow one of the following methods.

### Swift Package Manager (All platforms)
As of Xcode 11 SPM integrates nicely with Xcode. This means that installing dependencies with Xcode support is super easy. To add the dependency using Swift Package Manager do the following steps:

1. Select the desired project and choose the `Swift Packages` tab of your project.
2. Tap on the + button.
3. Enter `https://github.com/sanderrouk/Promise-Swift` onto the search bar and click next.
4. Choose the `Version` option leaving the selection on `Up to Next Major` option.
5. Click Next.
6. Click Finish.
7. Either create a separate file for it or add `import Promise` in the file where you want to use it.

### Carthage (MacOS or iOS)
1. Add `github "sanderrouk/Promise-Swift" ~> 1.0.0` project to your Cartfile.
2. Run `$ carthage update`
3. [Do the additional steps required for carthage frameworks.](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application)
4. Either create a separate file for it or add `import PinKit` in the file where you want to use it.

## Usage
Promise works just like any other promises framework making the syntax very familiar.

```swift
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

/// These two can't be called on the same promise
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
```

## License
The project is under the MIT licence meaning you can use this project however you want.