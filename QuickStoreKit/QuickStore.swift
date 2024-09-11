

import Foundation

public protocol QuickStoreProtocol {
    associatedtype Key: RawRepresentable
    static var isAppGroup: Bool { get }
    static var store: QuickStoreHandleProtocol { get }
    static var excludeStoreCache: Bool { get }
    static var crypt: QuickStoreCryptProtocol? { get }
}

public class GlobalConfig {
    public static var storeType: QuickStoreHandleProtocol.Type = FileStore.self
    public static var cryptType: QuickStoreCryptProtocol.Type = SimpleCrypt.self
    static var storeDic = Safe([String: QuickStoreHandleProtocol]())

    static func set(_ key: String, store: QuickStoreHandleProtocol) {
        storeDic.value[key] = store
    }

    static func get(key: String) -> QuickStoreHandleProtocol? {
        return storeDic.value[key]
    }
}

extension QuickStoreProtocol where Key.RawValue == String {
    public static var isAppGroup: Bool {
        return false
    }

    public static var crypt: QuickStoreCryptProtocol? {
        return GlobalConfig.cryptType.init()
    }

    public static var store: QuickStoreHandleProtocol {
        if let store = GlobalConfig.get(key: className) {
            return store
        }
        let store = GlobalConfig.storeType.init(isAppGroup, options: ["id": className])
        GlobalConfig.set(className, store: store)
        return store
    }

    private static var className: String {
        let key = "\(self)"
        return key
    }

    public static func set(_ key: String, value: Any?) {
        let newKey = "\(className)." + key

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
        let newKey = "\(className)." + forKey
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

        if Target.excludeStoreCache {
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
            return nil
        }
    }
}
