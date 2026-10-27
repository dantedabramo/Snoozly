//
//  SetupProfileSheetView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import SwiftUI

// MARK: - SetupProfileSheetView

struct SetupProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKey.profileName) private var savedName = ""
    @AppStorage(AppStorageKey.profileIcon) private var savedIcon = "moon.stars.fill"

    @State private var displayName: String = ""
    @State private var selectedIcon: String = "moon.stars.fill"

    private let availableIcons = [
        "moon.stars.fill",
        "sparkles",
        "bed.double.fill",
        "hare.fill",
        "tortoise.fill",
        "cat.fill",
        "bird.fill",
        "zzz"
    ]

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background
                Color.midnightNavy
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.nightSurface.opacity(0.35), Color.midnightNavy],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // MARK: - Content
                ScrollView {
                    VStack(spacing: 24) {
                        avatarPreview
                        nameInputField
                        iconPickerGrid
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Setup Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.lavendar)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveProfile()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isValid ? Color.starlightGold : Color.lavendar.opacity(0.3))
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                displayName = savedName
                selectedIcon = savedIcon.isEmpty ? "moon.stars.fill" : savedIcon
            }
        }
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.dreamPurple.opacity(0.2))
                    .frame(width: 110, height: 110)
                    .blur(radius: 12)

                Circle()
                    .fill(Color.nightSurface.opacity(0.8))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))

                Image(systemName: selectedIcon)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.starlightGold)
            }

            Text(displayName.isEmpty ? "Display Name" : displayName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(displayName.isEmpty ? Color.lavendar.opacity(0.5) : Color.white)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Input Field

    private var nameInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Name")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.lavendar)

            TextField("Enter your name", text: $displayName)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Icon Picker

    private var iconPickerGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Profile Icon")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.lavendar)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                ForEach(availableIcons, id: \.self) { icon in
                    let isSelected = selectedIcon == icon

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedIcon = icon
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.dreamPurple.opacity(0.4) : Color.white.opacity(0.07))
                                .frame(height: 60)
                                .overlay {
                                    Circle()
                                        .strokeBorder(isSelected ? Color.starlightGold : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
                                }

                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.starlightGold : Color.white.opacity(0.85))

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.starlightGold)
                                    .background(Circle().fill(Color.midnightNavy))
                                    .offset(x: 18, y: -18)
                            }
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - Save Action

    private func saveProfile() {
        guard isValid else { return }
        savedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        savedIcon = selectedIcon
        dismiss()
    }
}

#Preview {
    SetupProfileSheetView()
}
