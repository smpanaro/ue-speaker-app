//
//  UEBluetoothConnection.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/28/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

/// Discovers, connects and sends commands to a UE speaker via BLE. Only works when the speaker is off.
public class UELowEnergyBluetoothConnection: NSObject {

    public var isConnected = false

    enum Service: String {
        // Used in Android App
        case primary = "757ed3e4-1828-4a0c-8362-c229c3a6da72"

        // Others
        case genericAccess = "00001800-0000-1000-8000-00805f9b34fb"
        case genericAttribute = "00001801-0000-1000-8000-00805f9b34fb"

        var uuid: CBUUID { return CBUUID(string: self.rawValue) }
    }

    enum Characteristic: String {
        // Used in Android App
        case powerOn = "c6d6dc0d-07f5-47ef-9b59-630622b01fd3"
        case alarm = "16e005bb-3862-43c7-8f5c-6f654a4ffdd2"
        case batteryLevel = "00002a19-0000-1000-8000-00805f9b34fb"
        case deviceName = "00002a00-0000-1000-8000-00805f9b34fb" // r/w
        case firmwareVersion = "00002a28-0000-1000-8000-00805f9b34fb"
        case serialNumber = "00002a25-0000-1000-8000-00805f9b34fb"

        // Others
        case appearance = "00002a01-0000-1000-8000-00805f9b34fb"
        case modelNumber = "00002a24-0000-1000-8000-00805f9b34fb"
        case unkownUseAtYourOwnRisk = "16e009bb-3862-43c7-8f5c-6f654a4ffdd2" // :)

        var uuid: CBUUID { return CBUUID(string: self.rawValue) }
    }

    var manager: CBCentralManager!
    var device: CBPeripheral?

    private var didConnectCallback: (() -> Void)?
    private var powerOnCallback: (() -> Void)?

    public func connect(completion: (() -> Void)?) {
        guard manager == nil else { return }

        didConnectCallback = completion
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    func scan() {
        // Seems like none of the services are advertised so have to query for everything and filter.
        manager.scanForPeripherals(withServices: nil, options: nil)
    }

    public func rescan(completion: (() -> Void)?) {
        didConnectCallback = completion
        manager.stopScan()
        scan()
    }

    public func requestPowerOn(completion: (() -> Void)? = nil) {
        powerOnCallback = completion
        if let service = device?.services?.filter({ $0.uuid == Service.primary.uuid }).first,
            let powerCharacteristic = service.characteristics?.filter({ $0.uuid == Characteristic.powerOn.uuid }).first,
            let hostMAC = Preferences.shared.hostMAC,
            // Not sure why, but you're supposed to pad with a 0x01. Might be that 1/0 is on/off (but this is always on).
            let value = (hostMAC+"01").hexadecimal {
            device?.writeValue(value,
                                  for: powerCharacteristic,
                                  type: powerCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        }
    }
}

extension UELowEnergyBluetoothConnection: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
          case .unknown:
            os_log(.debug, "CoreBluetooth central.state is .unknown")
          case .resetting:
            os_log(.debug, "CoreBluetooth central.state is .resetting")
          case .unsupported:
            os_log(.debug, "CoreBluetooth central.state is .unsupported")
          case .unauthorized:
            os_log(.debug, "CoreBluetooth central.state is .unauthorized")
          case .poweredOff:
            os_log(.debug, "CoreBluetooth central.state is .poweredOff")
          case .poweredOn:
            os_log(.debug, "CoreBluetooth central.state is .poweredOn")
            os_log("Starting BLE peripheral scan.")
            scan()
        @unknown default:
            os_log(.debug, "CoreBluetooth central.state is unkown default")
        }
    }


    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let value = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
            let deviceMAC = Preferences.shared.deviceMAC?.hexadecimal,
            value == deviceMAC {

            os_log("Found speaker via BLE: %@", peripheral)
            central.stopScan()

            device = peripheral
            device?.delegate = self

            central.connect(peripheral, options: nil)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Connected to speaker via BLE: %@", peripheral)
        device?.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Disconnect from speaker via BLE: %@", peripheral)
        isConnected = false
    }
}

extension UELowEnergyBluetoothConnection: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logError(errorFormat: "Error discovering service: %@", error: error)
        if let primaryService = peripheral.services?.filter({ $0.uuid == Service.primary.uuid }).first {
            device?.discoverCharacteristics(nil, for: primaryService)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logError(errorFormat: "Error discovering characteristic: %@", error: error)
        if service.characteristics?.filter({ $0.uuid == Characteristic.powerOn.uuid }).first != nil {
            isConnected = true
            didConnectCallback?()
            didConnectCallback = nil
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        logError(errorFormat: "Error writing value for characteristic: %@", error: error)
        if error == nil {
            powerOnCallback?()
            powerOnCallback = nil
        }
    }

    func logError(errorFormat: StaticString, error: Error?) {
        precondition(errorFormat.withUTF8Buffer { buf in
            buf.count > 1 &&
                buf[buf.index(buf.endIndex, offsetBy: -2)] == "%".firstUnicodeScalarCodePoint &&
                buf[buf.index(buf.endIndex, offsetBy: -1)] == "@".firstUnicodeScalarCodePoint
        }, "error format string \(errorFormat) must end with an instance of '%@'")
        guard let description = error?.localizedDescription else { return }

        os_log(.error, errorFormat, description)
    }
}

extension String {
    var firstUnicodeScalarCodePoint: UInt32 {
        return unicodeScalars[unicodeScalars.startIndex].value
    }
}
