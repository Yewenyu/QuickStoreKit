

import Foundation

public protocol QuickStoreProtocol {
    associatedtype Key: RawRepresentable
    static var isAppGroup: Bool { get }
    static var store: StoreData { get }
    static var identify: String? { get }
    static var addFilterCach: Bool { get }
    static var crypt: QuickStoreCryptProtocol? { get }
}

public var GlobelCrypt: QuickStoreCryptProtocol = SimpleCrypt()
extension QuickStoreProtocol {
    public static var isAppGroup: Bool {
        return false
    }

    public static var crypt: QuickStoreCryptProtocol? {
        return GlobelCrypt
    }

    public static var identify: String? {
        let identify: String? = isAppGroup ? nil : "\(self)"
        return identify
    }

    public static var store: StoreData {
        return FileStore(identify)
    }
}

@propertyWrapper public class QuickStore<Target: QuickStoreProtocol, Value> where Target.Key.RawValue == String {
    public var key: Target.Key
    var cach: Bool
    var useMemeryCach: Bool = true

    public var otherKey: String? {
        didSet {
            current = getCach()
        }
    }

    var syncQueue = false
    var isInit = true
    public init(_ key: Target.Key, _ defaultValue: Value? = nil, _ safeQueue: DispatchQueue? = nil, cach: Bool = true, useMemeryCach: Bool = true, syncQueue: Bool = false) {
        var safeQueue = safeQueue
        if safeQueue == nil {
            safeQueue = SafeQueueHandle.getQueue("\(Target.self)")
        }

        if Target.addFilterCach {
            DispatchQueue.main.async {
                let key = FileStore.encodeKey("\(Target.self)")
                FilterKeys.filterKey?[key] = 0
            }
        }
        self.key = key
        queue = safeQueue!
        self.cach = cach
        self.useMemeryCach = useMemeryCach
        current = wrappedValue ?? defaultValue
        self.syncQueue = syncQueue
        isInit = false
//        self.wrappedValue = self.current
    }

    private var queue: DispatchQueue
    var current: Value? {
        set {
            if isInit {
                queueValue = newValue
            } else {
                var syncQueue = syncQueue
                if Thread.isMainThread {
                    syncQueue = true
                }
                queue.handle(syncQueue) {
                    self.queueValue = newValue
                }
            }
        }
        get {
            if Thread.isMainThread {
                return queueValue
            }
            return queue.sync { self.queueValue }
        }
    }

    private var queueValue: Value?

    public var wrappedValue: Value? {
        set {
            current = newValue
            setCach(newValue)
        }
        get {
            var value = current
            if !useMemeryCach {
                value = getCach() ?? current
            }
            if value == nil {
                value = getCach()
                current = value
            }
            return value
        }
    }

    public var cachValue: Value? {
        return getCach()
    }

    func setCach(_ value: Any?) {
        if cach {
            func set() {
                if let otherKey = otherKey {
                    Target.set(key.rawValue + otherKey, value: value)
                } else {
                    Target.set(key, value: value)
                }
            }
            queue.handle(syncQueue) {
                set()
            }
        }
    }

    func getCach<T>() -> T? {
        func get() -> T? {
            var v: T?
            if cach {
                var key: String = key.rawValue
                if let otherKey = otherKey {
                    key += otherKey
                }
                v = Target.value(key)
            }

            return v
        }
        if isInit {
            return get()
        }
        return queue.sync {
            return get()
        }
    }

    func update() {
        current = getCach()
    }
}

@propertyWrapper public class QuickStoreEnum<Target: QuickStoreProtocol, Value: RawRepresentable>: QuickStore<Target, Value> where Target.Key.RawValue == String {
    override public var wrappedValue: Value? {
        set {
            current = newValue
            setCach(newValue?.rawValue)
        }
        get {
            var v = current
            if !useMemeryCach, let value: Value.RawValue = getCach() {
                v = Value(rawValue: value)
                return current
            }
            if current == nil, let value: Value.RawValue = getCach() {
                v = Value(rawValue: value)
                current = v
            }
            return v
        }
    }
}

@propertyWrapper public class QuickStoreCodable<Target: QuickStoreProtocol, Value: Codable>: QuickStore<Target, Value> where Target.Key.RawValue == String {
    override public var cachValue: Value? {
        let data: Data? = getCach()
        return data?.toModel()
    }

    override public var wrappedValue: Value? {
        set {
            let data = newValue?.data
            current = newValue
            setCach(data)
        }
        get {
            var v = current
            if !useMemeryCach, let data: Data = getCach() {
                v = data.toModel()
                return v
            }
            if v == nil, let data: Data = getCach() {
                v = data.toModel()
                current = v
            }
            return v
        }
    }
}

extension QuickStoreProtocol where Key.RawValue == String {
    private static var objKey: String {
        let key = "\(self)"
        store.dataKey = key
        return key
    }

    public static func removeAllCach() {
        FileStore(identify).clearAll(objKey)
    }

    public static func set(_ key: String, value: Any?) {
        let newKey = "\(objKey)." + key

        var newValue: Data?

        if let value = value as? Data {
            newValue = value
        } else if let v = value {
            newValue = [v].toData
        }
        if let crypt = crypt {
            newValue = newValue.map {
                crypt.encrypt(key, value: $0)
            }
        }

        store.set(newKey, value: newValue)
    }

    public static func set(_ key: Key, value: Any?) {
        let newKey = key.rawValue
        set(newKey, value: value)
    }

    public static func value<T>(_ forKey: Key, type: T.Type, encrypt: Bool = true) -> T? {
        let newKey = forKey.rawValue
        return value(newKey, type: type, encrypt: encrypt)
    }

    public static func value<T>(_ forKey: String, type: T.Type, encrypt: Bool = true) -> T? {
        let newKey = "\(objKey)." + forKey
        var data = store.value(newKey)
        if let crypt = crypt {
            data = data.map {
                crypt.decrypt(newKey, value: $0)
            }
        }

        if T.self == Data.self {
            return data as? T
        } else if let data = data {
            do {
                let value = try JSONSerialization.jsonObject(with: data)
                if let value = value as? [T] {
                    return value.first
                }
            } catch _ {
                return nil
            }
        }
        return nil
    }

    static func value<T>(_ forKey: String, encrypt: Bool = true) -> T? {
        return value(forKey, type: T.self, encrypt: encrypt)
    }

    static func value<T>(_ forKey: Key, encrypt: Bool = true) -> T? {
        return value(forKey, type: T.self, encrypt: encrypt)
    }

    #if canImport(CryptoSwift)
        private static var aes: AES? {
            var identify = self.identify ?? "\(self)"
            while identify.count < 16 {
                identify += "5"
            }
            if identify.count > 16 {
                identify = identify.suffix(16).description
            }
            return try? AES(key: Array(identify.utf8), blockMode: CBC(iv: Array("0123456789ABCDEF".utf8)), padding: .pkcs5)
        }
    #endif
}

// struct WidgetShared : QuickStoreProtocol{
//    static var addFilterCach: Bool = false
//
//    enum Key : String {
//        case widgetUserExpireTime,widgetConnectStatus
//    }
//    static var isTargetShared: Bool = true
//    static var userExpireTime : String? {
//        get{
//            return value(.widgetUserExpireTime)
//        }
//
//        set{
//            set(.widgetUserExpireTime, value: newValue)
//        }
//    }
//
//    static var connectStatus : Bool {
//        get{
//            return value(.widgetConnectStatus) ?? false
//        }
//
//        set{
//            set(.widgetConnectStatus, value: newValue)
//        }
//    }
// }

#if canImport(SmartCodable)
    import SmartCodable
    @propertyWrapper public class QuickStoreModel<Target: QuickStoreProtocol, Value: SmartCodable>: QuickStore<Target, Value> where Target.Key.RawValue == String {
        override public var wrappedValue: Value? {
            set {
                let json = newValue?.toDictionary()
                current = newValue
                Target.set(key, value: json)
            }
            get {
                var v = current
                if v == nil {
                    if let json: [String: Any] = Target.value(key) {
                        v = Value.deserialize(from: json)
                    } else if let data: Data = getCach() {
                        v = Value.deserialize(from: data)
                    }
                    current = v
                }
                return v
            }
        }
    }
#endif

private class SafeQueueHandle {
    static var currentCount: Int = 0
    static var safeQueues = Safe([String: DispatchQueue]())

    static func getQueue(_ key: String) -> DispatchQueue {
        var queue = safeQueues.value[key]
        if queue == nil {
            queue = .init(label: "safeQueue.\(key)", qos: .background, autoreleaseFrequency: .workItem)
            safeQueues.value[key] = queue
        }
        return queue!
    }
}

public class StoreData {
    var dataKey: String = ""
    func set(_ key: String, value: Data?) {
    }

    func value(_ forKey: String) -> Data? {
        return nil
    }

    var identifier: String = ""
    init(_ identifier: String? = nil) {
        self.identifier = identifier ?? UserDefaultStore.sharedGroupIdentifier
    }

    public class func clearAll() {
    }

    public static var fileQueue = DispatchQueue(label: "\(StoreData.self).fileQueue", autoreleaseFrequency: .workItem)
}

public class UserDefaultStore: StoreData {
    static let shared = UserDefaultStore()
    enum Key: String {
        case udpRelay, dnsRelay, dnsRelayOnly, isDNSRelayKey

        /// 值为0：关闭，1：默认tcp，2：默认udp
        case speedDNSMode
    }

    var userDefaults: UserDefaults {
        return UserDefaults(suiteName: self.identifier)!
    }

    override func set(_ key: String, value: Data?) {
        let userDefaults = self.userDefaults
        userDefaults.setValue(value, forKey: key)
        userDefaults.synchronize()
    }

    override func value(_ forKey: String) -> Data? {
        return userDefaults.value(forKey: forKey) as? Data
    }

    func value<T>(_ forKey: String, type: T.Type) -> T? {
        return userDefaults.value(forKey: forKey) as? T
    }

    func value<T>(_ forKey: String) -> T? {
        return value(forKey, type: T.self)
    }

    func set(_ key: Key, value: Any?) {
        userDefaults.set(value, forKey: key.rawValue)
    }

    override public class func clearAll() {
        let userDefault = UserDefaults.standard
        let app = Bundle.main.bundleIdentifier ?? ""
        userDefault.removePersistentDomain(forName: app)
        userDefault.synchronize()
        var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last ?? ""
        path += "/Preferences"
        let list = try! FileManager.default.contentsOfDirectory(atPath: path)
        for l in list {
            let file = path + "/" + l
            if FileManager.default.fileExists(atPath: file), l.hasSuffix(".plist") {
                if l.contains("VPN") {
                    NSLog("")
                }
                let name = (l as NSString).deletingPathExtension as String
                let de = UserDefaults(suiteName: name)
                de?.removePersistentDomain(forName: name)
                try? FileManager.default.removeItem(atPath: file)
            }
        }
    }
}

extension UserDefaultStore {
    static let bundleID = Bundle.main.bundleIdentifier!

    public static var groupName = "group"
    public static var sharedGroupIdentifier: String {
        var array = bundleID.components(separatedBy: ".")
        if array.count > 3 {
            array.removeLast(array.count - 3)
        }
        array.insert(groupName, at: 0)
        let string = array.joined(separator: ".")
        return string
    }
}

extension Encodable {
    public var encoder: JSONEncoder {
        return .init()
    }

    public var data: Data? {
        return try? encoder.encode(self)
    }
}

public protocol DecodableExDecoder: Decodable {
    static var decoder: JSONDecoder { get }
}

extension Data {
    public func toModel<T: Decodable>() -> T? {
        do {
            let decoder: JSONDecoder
            if let type = T.self as? DecodableExDecoder.Type {
                decoder = type.decoder
            } else {
                decoder = JSONDecoder()
            }
            return try decoder.decode(T.self, from: self)
        } catch {
            #if DEBUG
                NSLog("\(Self.self).toModel: \(error)")
            #endif
            return nil
        }
    }
}

@propertyWrapper public class SafeProperty<Value> {
    public init(_ value: Value? = nil) {
        self.value = value
    }

    var value: Value?

    lazy var queue = DispatchQueue(label: "\(self)")

    public var wrappedValue: Value? {
        set {
            queue.async { [weak self] in
                self?.value = newValue
            }
        }
        get {
            return queue.sync { self.value }
        }
    }
}

public class Safe<Value> {
    public init(_ value: Value) {
        defaultValue = value
        _value = value
    }

    private let defaultValue: Value
    public var value: Value {
        set {
            _value = newValue
        }
        get {
            _value ?? defaultValue
        }
    }

    @SafeProperty<Value> private var _value
}

extension Array {
    public var toData: Data? {
        let data = try? JSONSerialization.data(withJSONObject: self, options: [])
        return data
    }
}

extension Data {
    public var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension DispatchQueue {
    @discardableResult
    func handle<T>(_ sync: Bool, handle: @escaping () -> (T)) -> T? {
        if sync {
            return self.sync(execute: handle)
        }
        async {
            _ = handle()
        }
        return nil
    }
}
