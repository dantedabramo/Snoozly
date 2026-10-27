//
//  AppGroup.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import Foundation

enum AppGroup {
    static let identifier = "group.com.dantedabramo.Snoozly"
    static let selectionKey = "quietAppsSelection"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
