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

    /// Hexadecimal string representation of `Data` object.

    var hexadecimal: String {
        return map { String(format: "%02x", $0) }
            .joined()
    }
}

extension String {

    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.

    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard data.count > 0 else { return nil }

        return data
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
