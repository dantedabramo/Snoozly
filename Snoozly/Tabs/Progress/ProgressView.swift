//
//  TonightView.swift
//  Snoozle
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI

struct ProgressView: View {
    var body: some View {
        ZStack {
            //MARK: - Background Color
            Color.midnightNavy
                .ignoresSafeArea()
            
            //MARK: - View
            Text("Progress")
        }
    }
}

#Preview {
    ProgressView()
}
