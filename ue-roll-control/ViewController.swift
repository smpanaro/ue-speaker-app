//
//  ViewController.swift
//  ue-roll-control
//
//  Created by Stephen Panaro on 9/25/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import UIKit
import CoreBluetooth
import UEControlKit

class ViewController: UIViewController {

    let rollMacAddress = Data(base64Encoded: "wCiNAg8r")! // c0288d020f2b -- TODO: Save automatically.

    let phoneMacAddressPlusOne = Data(base64Encoded: "zC23SLweAQ==")! // cc2db748bc1e01

    let primaryUERollServiceUUID = CBUUID(string: "757ed3e4-1828-4a0c-8362-c229c3a6da72")
    let powerOnCharacteristicUUID = CBUUID(string: "C6D6DC0D-07F5-47EF-9B59-630622B01FD3")

    var manager: CBCentralManager!
    var roll: CBPeripheral!
    var seenNames = Set<String>()

    var macScanner: UEMACAddressScanner!


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

//        manager = CBCentralManager(delegate: self, queue: nil)

        macScanner = UEMACAddressScanner(delegate: self)
        macScanner.start()
    }

}

extension ViewController: UEMACAddressScannerDelegate {
    func didDiscover(ueDeviceMacAddress: String) {
        print("Discovered UE MAC: \(ueDeviceMacAddress)")
    }

    func didDiscover(hostDeviceMacAddress: String) {
        print("Discovered host MAC: \(hostDeviceMacAddress)")
    }

    func didEncounterError(error: Error) {
        print("Encountered error: \(error.localizedDescription)")
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
          case .unknown:
            print("central.state is .unknown")
          case .resetting:
            print("central.state is .resetting")
          case .unsupported:
            print("central.state is .unsupported")
          case .unauthorized:
            print("central.state is .unauthorized")
          case .poweredOff:
            print("central.state is .poweredOff")
          case .poweredOn:
            print("central.state is .poweredOn")
            manager.scanForPeripherals(withServices: nil, options: nil)// [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [primaryUERollService]])
            manager.registerForConnectionEvents(options: nil)
        @unknown default:

            print("central.state is unknowndefault")
        }
    }


    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let value = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
            value == rollMacAddress {
            print("Found roll: \(peripheral)")
            central.stopScan()

            roll = peripheral
            roll.delegate = self

            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("did connect: \(peripheral)")

        print(roll.discoverServices(nil))
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("did discover services: \(String(describing: peripheral.services))")

        if let primaryService = peripheral.services?.filter({ $0.uuid == primaryUERollServiceUUID }).first {
            roll.discoverCharacteristics(nil, for: primaryService)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("characteristics: \(String(describing: service.characteristics))")


        if let powerCharacteristic = service.characteristics?.filter({ $0.uuid == powerOnCharacteristicUUID }).first {
            roll.discoverDescriptors(for: powerCharacteristic)

//            print(powerCharacteristic.properties.toString())
            peripheral.writeValue(phoneMacAddressPlusOne,
                                  for: powerCharacteristic,
                                  type: powerCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("discovered descriptors: \(String(describing: characteristic.descriptors))")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("wrote value for characteristic: \(characteristic.uuid) with error: \(String(describing: error))")
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        print("did update name: \(String(describing: peripheral.name))")
    }
}
