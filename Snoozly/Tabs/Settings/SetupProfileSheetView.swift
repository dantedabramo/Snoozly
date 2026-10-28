//
//  SetupProfileSheetView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - SetupProfileSheetView

struct SetupProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKey.profileName) private var savedName = ""
    @AppStorage(AppStorageKey.profileIcon) private var savedIcon = "moon.stars.fill"
    @AppStorage(AppStorageKey.profileImageData) private var savedImageData = Data()

    @State private var displayName: String = ""
    @State private var selectedIcon: String = "moon.stars.fill"
    @State private var profileImageData = Data()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

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
                        photoPicker
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
                profileImageData = savedImageData
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    profileImageData = image.jpegData(compressionQuality: 0.85) ?? Data()
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        profileImageData = data
                    }
                }
            }
        }
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconGradient(for: selectedIcon).opacity(0.3))
                    .frame(width: 110, height: 110)
                    .blur(radius: 12)

                Circle()
                    .fill(Color.nightSurface.opacity(0.8))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))

                if let image = UIImage(data: profileImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.starlightGold)
                }
            }

            Text(displayName.isEmpty ? "Display Name" : displayName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(displayName.isEmpty ? Color.lavendar.opacity(0.5) : Color.white)
        }
        .padding(.vertical, 8)
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Photo")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.lavendar)

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(ProfileActionButtonStyle())

                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                }
                .buttonStyle(ProfileActionButtonStyle())
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
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
                        Haptics.selection()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? iconGradient(for: icon) : LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
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
        Haptics.success()
        savedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        savedIcon = selectedIcon
        savedImageData = profileImageData
        dismiss()
    }

    private func iconGradient(for icon: String) -> LinearGradient {
        let index = availableIcons.firstIndex(of: icon) ?? 0
        let colors: [[Color]] = [
            [.dreamPurple, .moonlightBlue],
            [.starlightGold, .dreamCoral],
            [.restfulMint, .moonlightBlue],
            [.dreamCoral, .dreamPurple],
            [.moonlightBlue, .lavendar],
            [.starlightGold, .restfulMint],
            [.lavendar, .dreamCoral],
            [.dreamPurple, .starlightGold]
        ]
        let pair = colors[index % colors.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct ProfileActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .foregroundStyle(Color.midnightNavy)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Capsule().fill(NightGradient.lavender))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    SetupProfileSheetView()
}
