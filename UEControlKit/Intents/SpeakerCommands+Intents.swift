//
//  SpeakerCommands+Intents.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/29/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import Intents

public struct SpeakerCommands {
    public static var powerOnIntent: TogglePowerIntent {
        let intent = TogglePowerIntent()
        intent.state = .on
        return intent
    }

    public static var powerOffIntent: TogglePowerIntent {
        let intent = TogglePowerIntent()
        intent.state = .off
        return intent
    }
}
