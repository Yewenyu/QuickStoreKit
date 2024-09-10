

import Foundation

public class FileStore: StoreData {
    public static var cachPaths = Safe(Set<String>())

    lazy var mainDir: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let m = isShared ? FileManager().containerURL(forSecurityApplicationGroupIdentifier: self.identifier) : url
        _ = m.map {
            FileStore.cachPaths.value.insert($0.path)
        }
        return m ?? url
    }()

    var isShared = false
    override public init(_ identifier: String? = nil) {
        super.init(identifier)
        isShared = identifier == nil
    }

    private var targetDir: URL {
        return mainDir.appendingPathComponent(dataKey)
    }

    private var pathExt = "key"
    static func encodeKey(_ key: String) -> String {
        let split = key.components(separatedBy: ".").map { key in
            key.data(using: .utf8)?.map { UInt8((Int($0) + key.count) % 256) }.data?.base64EncodedString() ?? key
        }

        return split.joined(separator: ".")
    }

    func encodeKey(_ key: String) -> String {
        return FileStore.encodeKey(key)
    }

    override func set(_ key: String, value: Data?) {
        if !targetDir.fileIsExit {
            targetDir.dirCreate()
        }
        let key = encodeKey(key)
        let dir = targetDir.appendingPathComponent(key)
        if let value = value {
            try? value.write(to: dir)
        } else {
            try? FileManager.default.removeItem(at: dir)
        }
        setFilePath(dir)
    }

    override func value(_ forKey: String) -> Data? {
        let key = encodeKey(forKey)
        let dir = targetDir.appendingPathComponent(key)
        var data = try? Data(contentsOf: dir, options: [])
        if data == nil {
            let olddir = targetDir.appendingPathComponent(forKey).appendingPathExtension(pathExt)
            data = try? Data(contentsOf: olddir, options: [])
            if let data = data {
                try? FileManager.default.removeItem(at: olddir)
                try? data.write(to: dir)
            }
        }
        if data != nil {
            setFilePath(dir)
        }
        return data
    }

    func setFilePath(_ path: URL) {
        type(of: self).filePaths.value[path] = 0
    }

    static var filePaths = Safe([URL: Int]())

    override public class func clearAll() {
        filePaths.value.forEach {
            if FileManager.default.fileExists(atPath: $0.key.path) {
                try? FileManager.default.removeItem(at: $0.key)
            }
        }
    }

    public func clearAll(_ key: String) {
        let fileManager = FileManager.default
        let folderPath = mainDir
        do {
            let files = try fileManager.contentsOfDirectory(atPath: folderPath.path)
            for file in files {
                if file.contains(key) {
                    try fileManager.removeItem(at: folderPath.appendingPathComponent(file))
                }
                print("Found file: \(file)")
            }
        } catch {
            print("Error while enumerating files \(folderPath): \(error.localizedDescription)")
        }
    }
}

extension URL {
    var fileIsExit: Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    func dirCreate() {
        try? FileManager.default.createDirectory(at: self, withIntermediateDirectories: true)
    }
}
