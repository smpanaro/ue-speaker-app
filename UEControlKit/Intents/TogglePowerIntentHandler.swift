//
//  PowerIntentHandler.swift
//  UEControlIntents
//
//  Created by Stephen Panaro on 9/29/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import UIKit
import Intents
import os.log

public class TogglePowerIntentHandler: NSObject, TogglePowerIntentHandling {
    var connection: UELEBluetoothConnection!

    // TODO: Ew, switch to completion handlers?
    var latestCompletion: ((TogglePowerIntentResponse) -> Void)?

    public override init() {
        super.init()
        connection = UELEBluetoothConnection(delegate: self)
    }

    public func handle(intent: TogglePowerIntent, completion: @escaping (TogglePowerIntentResponse) -> Void) {
        os_log("Handling intent: %@", intent)

        latestCompletion = completion
        connection.connect()

        // Set up time out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.latestCompletion?(TogglePowerIntentResponse.notFound(state: intent.state))
            self?.latestCompletion = nil
        }
    }

    public func resolveState(for intent: TogglePowerIntent, with completion: @escaping (StateResolutionResult) -> Void) {
        os_log("Resolving state for intent: %@", intent)
        if intent.state == .unknown {
            completion(StateResolutionResult.needsValue())
        }
        else {
            completion(StateResolutionResult.success(with: intent.state))
        }
    }
}

extension TogglePowerIntentHandler: UELEBluetoothConnectionDelegate {
    public func didConnect() {
        os_log("Connected to speaker via BLE")
        connection.turnOn()
    }

    public func didPowerOn() {
        os_log("Turned speaker on")

        // TODO: Use a dedicated queue here.
        DispatchQueue.main.async { [weak self] in
            self?.latestCompletion?(TogglePowerIntentResponse.success(state: .on))
            self?.latestCompletion = nil
        }
    }
}
