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
import Intents

class ViewController: UIViewController {

    @IBOutlet weak var messageTextField: UITextView!
    @IBOutlet weak var speakerPowerButton: UIButton!

    var classicConnection: UEClassicBluetoothConnection!
    var bleConnection: UELowEnergyBluetoothConnection!

    var speakerConnection: UESpeakerConnection!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        speakerPowerButton.addTarget(self, action: #selector(didPressPowerButton), for: .touchUpInside)


//        classicConnection = UEClassicBluetoothConnection(delegate: self)
//        classicConnection.start()
//
//        bleConnection = UELowEnergyBluetoothConnection()
//        bleConnection.connect { [weak self] in
//            os_log("Connected to speaker via BLE")
//            DispatchQueue.main.async {
//                self?.refreshUI()
//            }
//        }

        speakerConnection = UESpeakerConnection(stateDidChange: speakerStateChanged)
        speakerConnection.connect()

        refreshUI()

        #if targetEnvironment(simulator)
            // Test Shortcuts without Bluetooth
            submitShortcutSuggestions()
        #endif

        if Preferences.shared.hostMAC != nil && Preferences.shared.deviceMAC != nil {
            submitShortcutSuggestions()
        }
    }

    func speakerStateChanged(newState: UESpeakerConnection.State) {
        os_log("New speaker state: %@", newState.rawValue)
        switch speakerConnection.state {
        case .on:
            handleSpeakerTurnedOn()
        default: break
        }

        DispatchQueue.main.async { self.refreshUI() }
    }

    func handleSpeakerTurnedOn() {
        guard
            Preferences.shared.hostMAC == nil || Preferences.shared.deviceMAC == nil
            else { return }

        speakerConnection.requestDeviceMAC { [weak speakerConnection, weak self] deviceMAC in
            speakerConnection?.requestHostMAC { hostMAC in
                Preferences.shared.deviceMAC = deviceMAC
                Preferences.shared.hostMAC = hostMAC
                DispatchQueue.main.async {
                     // Now that we have both MACs, we can enable Shortcuts.
                    self?.submitShortcutSuggestions()
                    self?.refreshUI()
                }
            }
        }
    }

    @objc
    func didPressPowerButton() {
//        if bleConnection.isConnected {
//            bleConnection.requestPowerOn()
//        }
//        else if classicConnection.isConnected {
//            classicConnection.requestPowerOff()
//        }
//        speakerPowerButton.setTitle("...", for: .normal)
//
        switch speakerConnection.state {
        case .on:
            speakerConnection.requestPowerOff()
        case .off:
            speakerConnection.requestPowerOn()
        case .unknown: break
        }
    }

    func refreshUI() {
//        let buttonTitle = bleConnection.isConnected ? "Turn speaker on" : classicConnection.isConnected ? "Turn speaker off" : ""
//        speakerPowerButton.setTitle(buttonTitle, for: .normal)
//        speakerPowerButton.isEnabled = bleConnection.isConnected || classicConnection.isConnected
//
//        let macText = Preferences.shared.hostMAC != nil && Preferences.shared.deviceMAC != nil ?
//            "Your MAC: \(Preferences.shared.hostMAC!)\nSpeaker MAC: \(Preferences.shared.deviceMAC!)" :
//            "Performing setup, please power on and connect your speaker."
//        let speakerState = bleConnection.isConnected ? "Speaker off" : classicConnection.isConnected ? "Speaker on" : "Scanning..."
//        messageTextField.text = [macText, speakerState].joined(separator: "\n")

        let buttonTitle = speakerConnection.state == .on ? "Turn speaker off" : speakerConnection.state == .off ? "Turn speaker on" : ""
        speakerPowerButton.setTitle(buttonTitle, for: .normal)
        speakerPowerButton.isEnabled = [.on, .off].contains(speakerConnection.state)

        let macText = Preferences.shared.hostMAC != nil && Preferences.shared.deviceMAC != nil ?
            "Your MAC: \(Preferences.shared.hostMAC!)\nSpeaker MAC: \(Preferences.shared.deviceMAC!)" :
            "Performing setup, please power on and connect your speaker."
        let speakerState = speakerConnection.state == .unknown ? "Scanning..." : "Speaker \(speakerConnection.state.rawValue)"
        messageTextField.text = [macText, speakerState].joined(separator: "\n")
    }

    func submitShortcutSuggestions() {
        INVoiceShortcutCenter.shared.setShortcutSuggestions([
            INShortcut(intent: SpeakerCommands.powerOnIntent), INShortcut(intent: SpeakerCommands.powerOffIntent)].compactMap({$0}))
    }
}

extension ViewController: UEClassicBluetoothConnectionDelegate {
    func didConnect(connection: UEClassicBluetoothConnection) {
        guard
            Preferences.shared.hostMAC == nil || Preferences.shared.deviceMAC == nil
            else {
                DispatchQueue.main.async { self.refreshUI() }
                return
        }

        connection.requestDeviceMAC { [weak connection, weak self] deviceMAC in
            connection?.requestHostMAC { hostMAC in
                Preferences.shared.deviceMAC = deviceMAC
                Preferences.shared.hostMAC = hostMAC
                DispatchQueue.main.async {
                     // Now that we have both MACs, we can enable Shortcuts.
                    self?.submitShortcutSuggestions()
                    self?.refreshUI()
                }
            }
        }
    }

    func didDisconnect(connection: UEClassicBluetoothConnection) {
        DispatchQueue.main.async {
            self.refreshUI()
            self.bleConnection.rescan() {}
        }
    }

    func didEncounterError(error: Error) {
        os_log("Encountered error: ", error.localizedDescription)

        DispatchQueue.main.async {
            self.messageTextField.text = "Encountered error: \(error.localizedDescription)"
        }
    }
}
