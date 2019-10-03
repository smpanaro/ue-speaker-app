//
//  UEClassicBluetoothConnection.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/27/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import ExternalAccessory
import os.log

/// Discovers, connects and sends commands to a UE speaker via Bluetooth classic. Only works when the speaker is on.
public class UEClassicBluetoothConnection {

    public var isConnected = false
    public var delegate: UEClassicBluetoothConnectionDelegate?

    let ueRollProtocol = "com.logitech.ue.ueroll"

    let manager: EAAccessoryManager
    var channel: AccessoryChannel?

    var syncQueue = DispatchQueue(label: "com.hedgemereapps.ue-classic-bt-conn",
                                  qos: .utility,
                                  attributes: [],
                                  autoreleaseFrequency: .inherit,
                                  target: DispatchQueue.global(qos: .utility))

    var isStarted = false

    struct CommandCallbackPair {
        let command: UEClassicBluetoothCommand
        let callback: (String) -> Void
    }
    var pendingResponses = [CommandCallbackPair]()

    var didConnectCallback: (() -> Void)?

    public init(delegate: UEClassicBluetoothConnectionDelegate? = nil) {
        manager = EAAccessoryManager.shared()
        self.delegate = delegate
    }

    deinit {
        if (isStarted) { stop() }
    }

    public func start(completion: (() -> Void)? = nil) {
        guard !isStarted else {
            delegate?.didEncounterError(error: UEClassicBluetoothError.alreadyStarted)
            return
        }

        didConnectCallback = completion

        NotificationCenter.default.addObserver(self, selector: #selector(accesoryDidConnect), name: NSNotification.Name.EAAccessoryDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accesoryDidDisconnect), name: NSNotification.Name.EAAccessoryDidDisconnect, object: nil)
        manager.registerForLocalNotifications()

        // Capture already-connected accessories.
        manager.connectedAccessories.forEach { [weak self] accessory in
            self?.syncQueue.async { [weak self] in
                self?.connect(accessory: accessory)
            }
        }
    }

    public func stop() {
        guard isStarted else {
            delegate?.didEncounterError(error: UEClassicBluetoothError.notStarted)
            return
        }

        if let accessory = channel?.session.accessory {
            disconnect(accessory: accessory)
        }

        manager.unregisterForLocalNotifications()
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    func accesoryDidConnect(notif: NSNotification) {
        guard
            let userInfo = notif.userInfo,
            let accessory = userInfo[EAAccessoryKey] as? EAAccessory
            else { return }

        syncQueue.async { [weak self] in
            self?.connect(accessory: accessory)
        }
    }

    @objc
    func accesoryDidDisconnect(notif: NSNotification) {
        guard
            let userInfo = notif.userInfo,
            let accessory = userInfo[EAAccessoryKey] as? EAAccessory
            else { return }

        syncQueue.async { [weak self] in
            self?.disconnect(accessory: accessory)
        }
    }

    func connect(accessory: EAAccessory) {
        guard
            accessory.protocolStrings.contains(ueRollProtocol),
            channel == nil,
            let session = EASession(accessory: accessory, forProtocol: ueRollProtocol)
            else { return }

        channel = AccessoryChannel(session: session, delegate: self)
        isConnected = true
        delegate?.didConnect(connection: self)
        didConnectCallback?()
    }

    func disconnect(accessory: EAAccessory) {
        channel?.close()
        channel = nil
        isConnected = false
        delegate?.didDisconnect(connection: self)
    }

    public func requestHostMAC(completion: @escaping (String) -> Void) {
        channel?.write(data: UEClassicBluetoothCommands.queryHostBluetoothAddress.payload())
        pendingResponses.append(CommandCallbackPair(command: UEClassicBluetoothCommands.returnHostBluetoothAddress, callback: completion))
    }

    public func requestDeviceMAC(completion: @escaping (String) -> Void) {
        channel?.write(data: UEClassicBluetoothCommands.queryDeviceBluetoothAddress.payload())
        pendingResponses.append(CommandCallbackPair(command: UEClassicBluetoothCommands.returnDeviceBluetoothAddress, callback: completion))
    }

    public func requestPowerOff() {
        channel?.write(data: UEClassicBluetoothCommands.masterRemoteOff.payload())
    }

    func handlePacket(packet: Data) {
        guard
            let code = UEClassicBluetoothCommand.parseCommandCode(payload: packet)
            else { return }

        var parsed: String
        switch code {
        case UEClassicBluetoothCommands.returnHostBluetoothAddress.code: fallthrough
        case UEClassicBluetoothCommands.returnDeviceBluetoothAddress.code:
            guard let mac = parseMacAddress(response: packet) else { return }
            parsed = mac
        default:
            return
        }

        let matchCriteria: (CommandCallbackPair) -> Bool = { $0.command.code == code }
        let matchingPairs = pendingResponses.filter(matchCriteria)
        pendingResponses.removeAll(where: matchCriteria)

        matchingPairs.forEach { pair in
            pair.callback(parsed)
        }

        // Send ack.
        // Not sure if this is required, but mimics the Android app and seems polite.
        channel?.write(data: UEClassicBluetoothCommand(code: code).ackPayload())
    }

    func parseMacAddress(response: Data) -> String? {
        if response.count != 9 {
            delegate?.didEncounterError(error: UEClassicBluetoothError.unexpectedResponse(response: response.hexadecimal))
            return nil
        }

        // Discard the leading 3 bytes, which contain metadata.
        return response.subdata(in: 3..<9).hexadecimal
    }
}

extension UEClassicBluetoothConnection: AccessoryChannelDelegate {
    func didReceive(packet: Data) {
        os_log("Received classic bluetooth packet: %@", packet.hexadecimal)
        syncQueue.async { [weak self] in
            self?.handlePacket(packet: packet)
        }
    }
}

public protocol UEClassicBluetoothConnectionDelegate {
    /// Called when the speaker connects this connection.
    func didConnect(connection: UEClassicBluetoothConnection)

    /// Called when the speaker disconnects this connection.
    func didDisconnect(connection: UEClassicBluetoothConnection)

    /// Called whenever there's an error, duh.
    func didEncounterError(error: Error)
}

public enum UEClassicBluetoothError: Error {
    case alreadyStarted
    case notStarted
    case unexpectedResponse(response: String)
}

extension UEClassicBluetoothError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyStarted:
            return NSLocalizedString(
                "Scanner is already started. Can't start again.",
                comment: ""
            )
        case .notStarted:
            return NSLocalizedString(
                "Scanner isn't started. Can't stop it.",
                comment: ""
            )
        case .unexpectedResponse(let response):
            return NSLocalizedString("Recieved unexpected response from speaker: \(response)", comment: "")
        }
    }
}
