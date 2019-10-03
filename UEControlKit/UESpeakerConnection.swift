//
//  UESpeakerConnection.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 10/3/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import os.log

/// Manages the connection to a UE speaker and allows interaction.
public class UESpeakerConnection {

    public enum State: String {
        case on
        case off
        case unknown
    }

    public var state: State {
        didSet {
            stateDidChangeCallback(state)
        }
    }

    let classicConnection: UEClassicBluetoothConnection
    let bleConnection: UELowEnergyBluetoothConnection

    var stateDidChangeCallback: ((State) -> Void)

    public init(stateDidChange: @escaping ((State) -> Void)) {
        classicConnection = UEClassicBluetoothConnection()
        bleConnection = UELowEnergyBluetoothConnection()
        state = .unknown
        stateDidChangeCallback = stateDidChange
        classicConnection.delegate = self
    }

    public func connect() {
        classicConnection.start()
        bleConnection.connect() { [weak self] in
            self?.state = .off
        }
    }

    public func requestPowerOn() {
        guard state == .off else {
            os_log(.error, "Can't request power on for a speaker that is %@", state.rawValue)
            return
        }

        bleConnection.requestPowerOn()
        state = .unknown
    }

    public func requestPowerOff() {
        guard state == .on else {
            os_log(.error, "Can't request power off for a speaker that is %@", state.rawValue)
            return
        }

        classicConnection.requestPowerOff()
        state = .unknown
    }

    public func requestHostMAC(completion: @escaping (String) -> Void) {
        guard state == .on else {
            os_log(.error, "Can't request host MAC from a speaker that is %@", state.rawValue)
            return
        }

        classicConnection.requestHostMAC(completion: completion)
    }

    public func requestDeviceMAC(completion: @escaping (String) -> Void) {
        guard state == .on else {
            os_log(.error, "Can't request device MAC from a speaker that is %@", state.rawValue)
            return
        }

        classicConnection.requestDeviceMAC(completion: completion)
    }
}

extension UESpeakerConnection: UEClassicBluetoothConnectionDelegate {
    public func didConnect(connection: UEClassicBluetoothConnection) {
        os_log("Connected to speaker via Bluetooth classic")
        state = .on
    }

    public func didDisconnect(connection: UEClassicBluetoothConnection) {
        os_log("Disconnected from speaker via Bluetooth classic")
        // TODO: Better handle the case where the speaker is on but not connected.
        state = .unknown
        bleConnection.rescan() { [weak self] in
            self?.state = .off
        }
    }

    public func didEncounterError(error: Error) {
        os_log(.error, "Classic bluetooth connection encountered error: ", error.localizedDescription)
    }
}
