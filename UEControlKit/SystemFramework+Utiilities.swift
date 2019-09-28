//
//  Data+Utiilities.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/27/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import CoreBluetooth

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

extension Data: ExpressibleByIntegerLiteral {
    // Convert hex value 0x0201AE to Data 02 01 AE
    public init(integerLiteral value: Int) {

        var value = value
        var bytes = [UInt8]()
        while (value != 0) {
            let lo = UInt8(value & 255)
            bytes.append(lo)
            value = value >> 8
        }

        self = Data(bytes.reversed())
    }
}

extension OptionSet where RawValue: FixedWidthInteger {
    func elements() -> AnySequence<Self> {
        var remainingBits = rawValue
        var bitMask: RawValue = 1
        return AnySequence {
            return AnyIterator {
                while remainingBits != 0 {
                    defer { bitMask = bitMask &* 2 }
                    if remainingBits & bitMask != 0 {
                        remainingBits = remainingBits & ~bitMask
                        return Self(rawValue: bitMask)
                    }
                }
                return nil
            }
        }
    }
}

extension CBCharacteristicProperties {
    func toString() -> String {
        return elements().map({ $0.toSingleString() }).joined(separator: ", ")
    }

    func toSingleString() -> String{
        switch self {
        case .broadcast: return "broadcast"
        case .read: return "read"
        case .writeWithoutResponse: return "writeWithoutResponse"
        case .write: return "write"
        case .notify: return "notify"
        case .indicate: return "indicate"
        case .authenticatedSignedWrites: return "authenticatedSignedWrites"
        case .extendedProperties: return "extendedProperties"
        case .notifyEncryptionRequired: return "notifyEncryptionRequired"
        case .indicateEncryptionRequired: return "indicateEncryptionRequired"
        default:
            fatalError()
        }
    }
}
