//
//  UEClassicBluetoothConnection.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/27/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import ExternalAccessory

// Scan for the associated Bluetooth MAC addresses of UE speakers over the classic (non-LE) bluetooth channel.
public class UEMACAddressScanner {

    let ueRollProtocol = "com.logitech.ue.ueroll"

    let hostMACAddressCommand: Data = 0x0201AC // aka 428
    let ueMACAddressCommand: Data =   0x0201AE // aka 430

    // TODO: Should this live here, in UEMACAddressScanner?
    let powerOffCommand: Data = 0x0201B6 // Data(base64Encoded: "AgG2") // 0x02 01 B6 aka 438

    let manager: EAAccessoryManager
    var channel: AccessoryChannel?
    var delegate: UEMACAddressScannerDelegate?

    var syncQueue = DispatchQueue(label: "com.hedgemereapps.ue-mac-scanner", qos: .utility, attributes: [], autoreleaseFrequency: .inherit, target: nil)

    var isStarted = false

    var macBuffer = Data()

    // simple state machine
    enum State {
        case scanning
        case waitingForHostMAC
        case waitingForUEMAC
        case success
    }
    var state: State = .scanning

    public init(delegate: UEMACAddressScannerDelegate) {
        manager = EAAccessoryManager.shared()
        self.delegate = delegate
    }

    deinit {
        if (isStarted) { stop() }
    }

    public func start() {
        guard !isStarted else {
            delegate?.didEncounterError(error: UEMACScanError.alreadyStarted)
            return
        }

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
            delegate?.didEncounterError(error: UEMACScanError.notStarted)
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
            state == .scanning,
            let session = EASession(accessory: accessory, forProtocol: ueRollProtocol)
            else { return }

        channel = AccessoryChannel(session: session, delegate: self)

        requestHostMAC()
    }

    func requestHostMAC() {
        channel?.write(data: hostMACAddressCommand)
        state = .waitingForHostMAC
    }

    func requestDeviceMAC() {
        channel?.write(data: ueMACAddressCommand)
        state = .waitingForUEMAC
    }

    func disconnect(accessory: EAAccessory) {
        channel?.close()
        channel = nil
        state = .scanning
    }

    func parse(data: Data) {
        if state == .waitingForHostMAC, let hostMac = parseMacAddress(data: data) {
            delegate?.didDiscover(hostDeviceMacAddress: hostMac)
            requestDeviceMAC()
            return
        }

        if state == .waitingForUEMAC, let ueMac = parseMacAddress(data: data) {
            delegate?.didDiscover(ueDeviceMacAddress: ueMac)
            state = .success
            return
        }
    }

    func parseMacAddress(data: Data) -> String? {
         macBuffer.append(data)

        if macBuffer.count > 9 {
            delegate?.didEncounterError(error: UEMACScanError.unexpectedResponse(response: macBuffer.hexEncodedString()))
            // TODO: Reconnect?
            return nil
        }

        if macBuffer.count < 9 {
            // wait for more data
            return nil
        }

        // Discard the leading 3 bytes. Not sure why but they aren't part of the MAC.
        let macString = macBuffer.subdata(in: 3..<9).hexEncodedString()
        macBuffer = Data()
        return macString
    }
}

extension UEMACAddressScanner: AccessoryChannelDelegate {
    func didReceive(data: Data) {
        syncQueue.async { [weak self] in
            self?.parse(data: data)
        }
    }
}

public protocol UEMACAddressScannerDelegate {
    // Called with the Bluetooth MAC address of the UE device (e.g. Roll) once it is discovered.
    func didDiscover(ueDeviceMacAddress: String)

    // Called with the Bluetooth MAC address of the host device (e.g. phone or iPad)  once it is discovered.
    func didDiscover(hostDeviceMacAddress: String)

    // Called whenever there's an error, duh.
    func didEncounterError(error: Error)
}

public enum UEMACScanError: Error {
    case alreadyStarted
    case notStarted
    case unexpectedResponse(response: String)
}

extension UEMACScanError: LocalizedError {
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
