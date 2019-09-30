//
//  IntentHandler.swift
//  UEControlIntents
//
//  Created by Stephen Panaro on 9/29/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Intents
import UEControlKit

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        guard intent is TogglePowerIntent else {
            fatalError("Unhandled intent type: \(intent)")
        }
        return TogglePowerIntentHandler()
    }
}
