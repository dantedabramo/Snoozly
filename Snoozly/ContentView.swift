//
//  ContentView.swift
//  Snoozle
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Tonight", systemImage: "moon.stars.fill") {
                TonightView()
            }

            Tab("Schedule", systemImage: "calendar") {
                ScheduleView()
            }

            Tab("Progress", systemImage: "chart.bar.fill") {
                ProgressView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
