

import Foundation


public protocol QuickStoreHandleProtocol{
    init(_ isAppGroup: Bool,options:[String:Any]?)
    func set(_ key: String, value: Data?)
    func value(_ forKey: String) -> Data?
    var isAppGroup : Bool{get set}
}

class FileStore: QuickStoreHandleProtocol {
    required init(_ isAppGroup: Bool, options: [String : Any]? = nil) {
        self.isAppGroup = isAppGroup
        self.subDir = options?["id"] as? String ?? ""
    }
    
    
    var isAppGroup: Bool =  false
    var subDir: String = ""
    
    var mainDir: String = "QuickStoreDir"
    
    
    var identifier: String = ""
   
    
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
    public static var cachPaths = Safe(Set<String>())

    lazy var mainDirUrl: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let m = isAppGroup ? FileManager().containerURL(forSecurityApplicationGroupIdentifier: Self.sharedGroupIdentifier) : url
        _ = m.map {
            FileStore.cachPaths.value.insert($0.path)
        }
        return m ?? url
    }()
    

    private var targetDir: URL {
        return mainDirUrl.appendingPathComponent(mainDir).appendingPathComponent(subDir)
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

    func set(_ key: String, value: Data?) {
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

    func value(_ forKey: String) -> Data? {
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

    
}

extension URL {
    var fileIsExit: Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    func dirCreate() {
        try? FileManager.default.createDirectory(at: self, withIntermediateDirectories: true)
    }
}
