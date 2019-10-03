//
//  ClassicBluetoothCommands.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/30/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation

/// The various types of ack responses.
struct AckResponse {
    static var ok: UInt8 = 0
}

/// A single command that can either be sent to or received from the UE speaker.
struct UEClassicBluetoothCommand {
    /// Unique identifier for each command, passed in the message header.
    let code: UInt16

    // Convenience for splitting the code into bytes.
    var codeMSB: UInt8 { return UInt8((code >> 8) & 0xFF) }
    var codeLSB: UInt8 { return UInt8(code & 0xFF) }

    init(code: UInt16) {
        self.code = code
    }

    /// Construct a properly formed payload for delivery to the remote Bluetooth device.
    func payload(with body: Data? = nil) -> Data {
        let bodyByteCount = body?.count ?? 0
        var payload = Data(capacity: bodyByteCount + 3)

        let messageLength = UInt8(bodyByteCount + 2)
        payload.append(contentsOf: [messageLength, codeMSB, codeLSB])
        if let body = body {
            payload.append(body)
        }

        return payload
    }

    /// Construct an ack payload for this command.
    func ackPayload() -> Data {
        // Acks are 5 bytes, first 3 are same header as any other command:
        // [1 byte length]
        // [ack code MSB]
        // [ack code LSB]
        // [acknowledged command code MSB]
        // [acknowledged command code LSB]
        // [1 byte ack response] -- either ok or some error
        return UEClassicBluetoothCommands.ack.payload(with: Data([codeMSB, codeLSB, AckResponse.ok]))
    }

    /// Parse the command code from a payload.
    static func parseCommandCode(payload: Data) -> UInt16? {
        guard payload.count >= 3 else { return nil }

        // Payload is:
        // [1 byte length]
        // [1 byte code most significant bit]
        // [1 byte code least significant bit]
        // [n bytes message]
        let codeMSB = UInt16(payload[1])
        let codeLSB = UInt16(payload[2])

        return (codeMSB << 8) | codeLSB
    }
}

/// Supported commands
struct UEClassicBluetoothCommands {
    /// Acknowledge receipt of a command.
    static var ack = UEClassicBluetoothCommand(code: 0)

    /// The Bluetooth MAC address of this iOS device
    static var queryHostBluetoothAddress = UEClassicBluetoothCommand(code: 428)
    static var returnHostBluetoothAddress = UEClassicBluetoothCommand(code: 429)

    /// The UE speaker's Bluetooth MAC address
    static var queryDeviceBluetoothAddress = UEClassicBluetoothCommand(code: 430)
    static var returnDeviceBluetoothAddress = UEClassicBluetoothCommand(code: 431)

    /// Turn the UE speaker off
    static var masterRemoteOff = UEClassicBluetoothCommand(code: 438)
}
