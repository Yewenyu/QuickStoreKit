//
//  QuickStoreCrypt.swift
//  QuickStoreKit
//
//  Created by ye on 2024/9/10.
//

import Foundation

public protocol QuickStoreCryptProtocol {
    init()
    func encrypt(_ key: String, value: Data) -> Data
    func decrypt(_ key: String, value: Data) -> Data
}

class SimpleCrypt: QuickStoreCryptProtocol {
    required init(){}
    func encrypt(_ key: String, value: Data) -> Data {
        let bytes = value.bytes
        let newBytes = bytes.map { (Int($0) + key.count % 255) % 255 }.map { UInt8($0) }
        let d = Data(newBytes)
        return d.base64EncodedData()
    }

    func decrypt(_ key: String, value: Data) -> Data {
        let d = value.base64EncodedData()
        let bytes = d.bytes
        let newBytes = bytes.map { (Int($0) + (255 - key.count % 255)) % 255 }.map { UInt8($0) }
        let data = Data(newBytes)
        return data
    }
}
