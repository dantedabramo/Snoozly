//
//  PermissionHint.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import SwiftUI
import UIKit

struct PermissionHint: View {
    var text: LocalizedStringKey
    var showsSettingsButton: Bool = true

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            OnboardingHint(text: text)

            if showsSettingsButton {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.lavendar)
                .frame(minHeight: 44, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
