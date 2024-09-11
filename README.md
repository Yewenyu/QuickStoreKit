# QuickStoreKit

QuickStoreKit is a comprehensive storage solution framework for iOS applications. It offers a streamlined API for managing persistent data with support for encryption, caching, and seamless integration with iOS development.

## Features

- **Persistent Storage**: Easily manage user data with robust file management systems.
- **Encryption**: Secure your data with powerful encryption protocols.
- **Caching**: Improve performance with advanced caching mechanisms.
- **Easy Integration**: QuickStoreKit is designed to be easily integrated into any existing iOS project.

## Requirements

- iOS 12.0+

## Installation

QuickStoreKit is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'QuickStoreKit'
```

## Usage

```swift
import QuickStoreKit

// Define a class that conforms to the QuickStoreProtocol
class Sample: QuickStoreProtocol {

    // Whether to exclude store cache (set to true)
    static var excludeStoreCache: Bool = true

    // Define a sample model that conforms to Codable for storage
    struct SampleModel: Codable {}

    // Enum to define different storage keys
    enum Key: String {
        case int, codable, key
    }

    // Use @QuickStore to store an Int value
    @QuickStore<Sample, Int>(.int) var intValue

    // Use @QuickStoreCodable to store a Codable object (SampleModel)
    @QuickStoreCodable<Sample, SampleModel>(.codable) var codable

    // Use @QuickStoreEnum to store an enum value
    @QuickStoreEnum<Sample, Key>(.key) var key
}
```

You can customize the encryption and decryption methods as well as the storage methods. The built-in SimpleCrypt and FileStore are available and used by default.
```swift
// Define a custom encryption class that conforms to QuickStoreCryptProtocol
class SampleCrypt: QuickStoreCryptProtocol {
    required init() {}

    // Implement the encrypt function
    func encrypt(_ key: String, value: Data) -> Data {
        // Add custom encryption logic here
        return .init()
    }

    // Implement the decrypt function
    func decrypt(_ key: String, value: Data) -> Data {
        // Add custom decryption logic here
        return .init()
    }
}

// Define a custom store class that conforms to QuickStoreHandleProtocol
class SampleStore: QuickStoreHandleProtocol {

    // Initializer to set whether the store is using App Group
    required init(_ isAppGroup: Bool, options: [String : Any]?) {
        self.isAppGroup = isAppGroup
    }

    // Implement the set function to store data
    func set(_ key: String, value: Data?) {
        // Add custom storage logic here
    }

    // Implement the value function to retrieve stored data
    func value(_ forKey: String) -> Data? {
        // Add custom data retrieval logic here
        return nil
    }

    // Whether the store is using App Group (default to false)
    var isAppGroup: Bool = false
}
```
Globally replace with the custom SampleCrypt and SampleStore.
```swift
// AppDelegate class
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Set the global encryption type to SampleCrypt
        GlobalConfig.cryptType = SampleCrypt.self

        // Set the global store type to SampleStore
        GlobalConfig.storeType = SampleStore.self

        // Override point for customization after application launch
        return true
    }
}
```
Specify the crypt and store of Sample to be replaced with SampleCrypt and SampleStore.
```swift
// Extend the Sample class to provide custom crypt and store handling
extension Sample {

    // Override the crypt property to use SampleCrypt
    static var crypt: (any QuickStoreCryptProtocol)? {
        return SampleCrypt()
    }

    // Override the store property to use SampleStore
    static var store: any QuickStoreHandleProtocol {
        return SampleStore(isAppGroup, options: [:])
    }
}

```

## License
This project is licensed under the MIT License - see the LICENSE file for details.
