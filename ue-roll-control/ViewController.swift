//
//  ViewController.swift
//  ue-roll-control
//
//  Created by Stephen Panaro on 9/25/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import UIKit
import UEControlKit
import os.log

class ViewController: UIViewController {

    @IBOutlet weak var messageTextField: UITextView!
    @IBOutlet weak var speakerPowerButton: UIButton!

    var macScanner: UEMACAddressScanner!
    var bleConnection: UELEBluetoothConnection!

    enum State: String {
        case initial = ""
        case scanningForMACs = "Turn on your UE Roll and connect to it."
        case scanningForBLE = "Scanning..."
        case bleConnected = "Connected."
        case turningOn = "Turning on..."
        case speakerOn = "Turned on!"
        case speakerOff = "Turned off!"
    }
    var state: State = .initial

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        speakerPowerButton.addTarget(self, action: #selector(didPressPowerButton), for: .touchUpInside)

        if Preferences.shared.hostMAC == nil || Preferences.shared.deviceMAC == nil {
            state = .scanningForMACs

            macScanner = UEMACAddressScanner(delegate: self)
            macScanner.start()
        }

        bleConnection = UELEBluetoothConnection(delegate: self)

        refreshUI()
    }

    @objc
    func didPressPowerButton() {
        state = .turningOn
        bleConnection.turnOn()
        refreshUI()
    }

    func refreshUI() {
        guard
            Preferences.shared.hostMAC != nil && Preferences.shared.deviceMAC != nil
            else { return }

        if [.initial, .scanningForMACs].contains(state) {
            state = .scanningForBLE
            bleConnection.connect()
        }

        speakerPowerButton.isUserInteractionEnabled = ![.initial, .scanningForMACs, .scanningForBLE, .turningOn].contains(state)

        messageTextField.text = "Your MAC: \(Preferences.shared.hostMAC!)\nSpeaker MAC: \(Preferences.shared.deviceMAC!)\n\(state.rawValue)"
    }
}

extension ViewController: UEMACAddressScannerDelegate {
    func didDiscover(ueDeviceMacAddress: String) {
        os_log("Discovered UE MAC: %@", ueDeviceMacAddress)
        Preferences.shared.deviceMAC = ueDeviceMacAddress
        DispatchQueue.main.async { self.refreshUI() }
    }

    func didDiscover(hostDeviceMacAddress: String) {
        os_log("Discovered host MAC: %@", hostDeviceMacAddress)
        Preferences.shared.hostMAC = hostDeviceMacAddress
        DispatchQueue.main.async { self.refreshUI() }
    }

    func didEncounterError(error: Error) {
        os_log("Encountered error: ", error.localizedDescription)

        DispatchQueue.main.async {
            self.messageTextField.text = "Encountered error: \(error.localizedDescription)"
        }
    }
}

extension ViewController: UELEBluetoothConnectionDelegate {
    func didConnect() {
        os_log("Connected to speaker via BLE")
        DispatchQueue.main.async {
            self.state = .bleConnected
            self.refreshUI()
        }
    }

    func didPowerOn() {
        os_log("Turned speaker on")
        DispatchQueue.main.async {
            self.state = .speakerOn
            self.refreshUI()
        }
    }
}
