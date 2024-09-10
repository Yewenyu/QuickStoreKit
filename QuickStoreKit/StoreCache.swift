

import Foundation

class FilterKeys: QuickStoreProtocol {
    static var isAppGroup: Bool = true
    static var excludeStoreCache: Bool = false

    enum Key: String {
        case filterKey
    }

    @QuickStore<FilterKeys, [String: Int]>(.filterKey, .init()) public static var filterKey
}

public class StoreCache: QuickStoreProtocol {
    public static var excludeStoreCache: Bool = true

    public enum Key: String {
        case customCachePath, defaultCachePath, currentCachSize
        case sharedPath, fileInfos, dirInfos
        case clearLevel, lastLevel
    }

    public static var isAppGroup: Bool = true

    @QuickStoreCodable<StoreCache, [CachInfo]>(.customCachePath, [.init(path: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!, filterKey: []), .init(path: NSTemporaryDirectory(), filterKey: [])]) var customCachePath
    @QuickStoreCodable<StoreCache, [CachInfo]>(.defaultCachePath, []) var defaultCachePath
    @QuickStore<StoreCache, Int64>(.currentCachSize, 0) public var currentCachSize
    @QuickStore<StoreCache, String>(.sharedPath) public var sharedPath
    @QuickStoreCodable<StoreCache, [FileAttribute]>(.fileInfos, []) var fileInfos
    @QuickStoreCodable<StoreCache, [FileAttribute]>(.dirInfos, []) var dirInfos

    @QuickStore<StoreCache, Int>(.clearLevel, 0) var clearLevel
    @QuickStore<StoreCache, Int>(.lastLevel, 0) var lastLevel

    public static let mbSize = 1024 * 1024
    public struct CachInfo: Codable {
        public init(path: String, filterKey: [String], maxSize: Int = 1024 * StoreCache.mbSize) {
            self.path = path
            self.filterKey = filterKey
            self.maxSize = maxSize
        }

        let path: String
        var filterKey: [String]
        let maxSize: Int
    }

    public struct FileAttribute: Codable {
        public init(path: String, size: Int64, subFiles: [FileAttribute] = []) {
            self.path = path
            self.size = size
            self.subFiles = subFiles
        }

        let path: String
        let size: Int64
        var subFiles: [FileAttribute] = []

        static func exploreFolder(atPath path: String, handleInfo: ((FileAttribute) -> Void)? = nil) -> FileAttribute {
            let fileManager = FileManager.default
            var totalSize: Int64 = 0
            var subFilesAttributes: [FileAttribute] = []

            if let files = try? fileManager.contentsOfDirectory(atPath: path) {
                for filePath in files {
                    let fullPath = (path as NSString).appendingPathComponent(filePath)

                    // 跳过隐藏文件
                    if filePath.hasPrefix(".") { continue }

                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                        if isDir.boolValue {
                            // 如果是文件夹，递归调用
                            let dirAttribute = exploreFolder(atPath: fullPath, handleInfo: handleInfo)
                            totalSize += dirAttribute.size
                            subFilesAttributes.append(dirAttribute)
                        } else {
                            // 如果是文件，获取文件大小
                            if let fileSize = sizeOfFile(path: fullPath) {
                                totalSize += fileSize
                                let att = FileAttribute(path: fullPath, size: fileSize)
                                subFilesAttributes.append(att)
                                handleInfo?(att)
                            }
                        }
                    }
                }
            }

            return FileAttribute(path: path, size: totalSize, subFiles: subFilesAttributes)
        }

        static func sizeOfFile(path: String) -> Int64? {
            let fileManager = FileManager.default
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                return attributes[.size] as? Int64
            } catch {
                print("Error getting file size: \(error)")
                return nil
            }
        }

        func filterMaxSize(_ maxSize: Int) -> Self {
            var att = self
            att.subFiles = att.subFiles.filter({
                $0.size > maxSize
            })
            att.subFiles = att.subFiles.map {
                $0.filterMaxSize(maxSize)
            }
            return att
        }
    }

    public static let shared = StoreCache()

    public func setInfo(_ info: CachInfo) {
        if customCachePath?.contains(where: {
            $0.path == info.path
        }) == false {
            customCachePath?.append(info)
        }
    }

    lazy var queue = DispatchQueue(label: "\(self).queue")

    public func getLog(_ directGet: Bool = false) -> [String: Any]? {
        let fileInfos = fileInfos ?? []
        let currentCachSize = self.currentCachSize ?? 0
        var canGet = directGet
        let currentMB = Int(currentCachSize) / StoreCache.mbSize
        if !canGet {
            if currentCachSize > StoreCache.mbSize * 100 {
                clearLevel = currentMB
                let last = lastLevel ?? 0
                let current = clearLevel ?? 0
                if last + 99 < current {
                    canGet = true
                }
            }
        }
        if canGet, currentMB > 10 {
            lastLevel = clearLevel

            var dic = [String: Any]()
            fileInfos.reversed().enumerated().forEach { v in
                dic["fileInfoName\(v.offset)"] = "\(v.element.path)"
                dic["fileInfoSize\(v.offset)"] = "\(v.element.size)"
            }
            dirInfos?.reversed().enumerated().forEach({ v in
                dic["dirInfo\(v.offset)"] = v.element.data.map { String(data: $0, encoding: .utf8) ?? "" }
            })
            dic["curerntCacheSize"] = self.currentCachSize ?? 0
            dic["isClear"] = directGet ? "1" : "0"
            return dic
        }

        return nil
    }

    public func check(_ complete: (() -> Void)? = nil) {
        queue.async {
            var fileInfos = [FileAttribute]()
            var dirInfos = [FileAttribute]()
            var allSize = Int64(0)
            let checkPaths = (self.customCachePath ?? []) + (self.defaultCachePath ?? [])
            for info in checkPaths {
                let (dirAtt, files) = self.getFolderSizeAndMaxSubFiles(info.path, maxFileCount: 10)
                fileInfos.append(contentsOf: files)
                allSize += dirAtt.size
                if dirAtt.size > StoreCache.mbSize * 100 {
                    let aa = dirAtt.filterMaxSize(StoreCache.mbSize * 100)
                    dirInfos.append(aa)
                }
            }
            fileInfos.sort {
                $0.size < $1.size
            }
            if fileInfos.count > 10 {
                fileInfos = fileInfos[fileInfos.count - 10 ..< fileInfos.count].map { $0 }
            }
            self.currentCachSize = allSize
            self.fileInfos = fileInfos
            self.dirInfos = dirInfos.sorted(by: {
                $0.size < $1.size
            })
            complete?()
        }
    }

    func getFolderSizeAndMaxSubFiles(_ path: String, maxFileCount: Int = 10) -> (FileAttribute, [FileAttribute]) {
        var fileInfos = [FileAttribute]()
        let att = FileAttribute.exploreFolder(atPath: path) { file in
            fileInfos.append(file)

            fileInfos = Dictionary(fileInfos.map {
                let url = URL(fileURLWithPath: $0.path)
                let path = url.deletingLastPathComponent().lastPathComponent + "/" + url.lastPathComponent
                return (path, $0)

            }, uniquingKeysWith: { _, v in
                v
            }).map { $0.value }
        }
        fileInfos.sort {
            $0.size < $1.size
        }
        if fileInfos.count > maxFileCount {
            fileInfos = fileInfos.reversed()[0 ..< maxFileCount].reversed().map { $0 }
        }
        return (att, fileInfos)
    }

    public func clearAll(_ checkSize: Bool = true, complete: (() -> Void)? = nil) {
        queue.async {
            var allSize = Int64(0)
            let filterKeys = FilterKeys.filterKey?.map { $0.key } ?? []
            while let last = self.fileInfos?.last {
                self.fileInfos?.removeLast()
                if last.size > 50 * StoreCache.mbSize {
                    try? FileManager.default.removeItem(atPath: last.path)
                } else {
                    var canDelete = true
                    for key in filterKeys {
                        if last.path.contains(key) {
                            canDelete = false
                            break
                        }
                    }
                    if canDelete {
                        try? FileManager.default.removeItem(atPath: last.path)
                    }
                }
            }
            self.clearLevel = 0
            self.lastLevel = 0

            for info in self.customCachePath ?? [] {
                var dirAtt = FileAttribute.exploreFolder(atPath: info.path)

                var canDelete = true
                if checkSize && dirAtt.size < info.maxSize {
                    canDelete = false
                }
                if canDelete {
                    self.clear(info.path, filters: info.filterKey + filterKeys)
                    dirAtt = FileAttribute.exploreFolder(atPath: info.path)
                }
                allSize += dirAtt.size
            }
            self.check(complete)
        }
    }

    func clear(_ path: String, filters: [String]) {
        let fileManager = FileManager.default
        let folderPath = URL(fileURLWithPath: path)

        let files = (try? fileManager.contentsOfDirectory(atPath: folderPath.path)) ?? []
        for file in files {
            var canDelete = true
            filters.forEach {
                if file.contains($0) {
                    canDelete = false
                }
            }
            if canDelete {
                do {
                    try fileManager.removeItem(at: folderPath.appendingPathComponent(file))
                } catch {
                    print("Error while enumerating files \(folderPath): \(error.localizedDescription)")
                }
            }
        }
    }
}
