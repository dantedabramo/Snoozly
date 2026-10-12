//
//  SnoozleApp.swift
//  Snoozle
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI

@main
struct SnoozleApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.9)) {
                            showSplash = false
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.04))))
                    .zIndex(1)
                }
            }
        }
    }
}
