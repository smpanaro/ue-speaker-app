//
//  Preferences.swift
//  UEControlKit
//
//  Created by Stephen Panaro on 9/27/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation

public class Preferences {

    public static let shared = Preferences()

    public var hostMAC: String? {
        get {
            return defaults.string(forKey: "host-mac")
        }
        set {
            defaults.set(newValue, forKey: "host-mac")
        }
    }

    public var deviceMAC: String? {
        get {
            return defaults.string(forKey: "device-mac")
        }
        set {
            defaults.set(newValue, forKey: "device-mac")
        }
    }

    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "group.hedgemereapps.ue-roll-control")!
    }
}
