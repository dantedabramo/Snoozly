//
//  SettingsView.swift
//  Snoozle
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            //MARK: - Background Color
            Color.midnightNavy
                .ignoresSafeArea()
            
            //MARK: - View
            Text("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
