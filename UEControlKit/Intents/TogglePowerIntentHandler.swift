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
    var speakerConnection: UESpeakerConnection!

    public func handle(intent: TogglePowerIntent, completion: @escaping (TogglePowerIntentResponse) -> Void) {
        os_log("Handling intent: %@", intent)
        speakerConnection = UESpeakerConnection { [weak self] newState in
            print("speaker state: \(newState.rawValue) intent state: \(intent.state == .on ? "on" : intent.state == .off ? "off" : "unknown")" )
            if (newState == .on && intent.state == .on) || (newState == .off && intent.state == .off) {
                DispatchQueue.main.async {
                    completion(TogglePowerIntentResponse.success(state: intent.state))
                }
            }
            else if (newState == .on && intent.state == .off) {
                print("Request power off")
                self?.speakerConnection.requestPowerOff()
            }
            else if (newState == .off && intent.state == .on) {
                print("Request power on")
                self?.speakerConnection?.requestPowerOn()
            }
        }
        speakerConnection.connect()

        // Set up time out.
//        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//            completion(TogglePowerIntentResponse.notFound(state: intent.state))
//        }
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
