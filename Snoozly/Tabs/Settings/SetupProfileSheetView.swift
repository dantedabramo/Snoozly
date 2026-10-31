//
//  SetupProfileSheetView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-23.
//

import SwiftUI
import PhotosUI

// MARK: - SetupProfileSheetView

struct SetupProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKey.profileName) private var savedName = ""
    @AppStorage(AppStorageKey.profileIcon) private var savedIcon = "moon.stars.fill"

    @State private var photoStore = ProfilePhotoStore.shared
    @State private var displayName: String = ""
    @State private var selectedIcon: String = "moon.stars.fill"
    @State private var draftPhoto: UIImage?
    @State private var removesPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shownPhoto: UIImage? {
        removesPhoto ? nil : (draftPhoto ?? photoStore.image)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.midnightNavy
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.nightSurface.opacity(0.35), Color.midnightNavy],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        avatarPreview
                        photoActions
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
                        Haptics.play(.tap)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.lavendar)
                    }
                    .accessibilityLabel("Cancel")
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
                    .accessibilityLabel("Save profile")
                    .accessibilityHint(isValid ? "" : "Enter a display name first")
                }
            }
            .onAppear {
                displayName = savedName
                selectedIcon = savedIcon.isEmpty ? "moon.stars.fill" : savedIcon
            }
            .onChange(of: pickerItem) { _, item in
                loadPickedPhoto(item)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    useDraftPhoto(image)
                }
                .ignoresSafeArea()
            }
        }
        .presentationHaptic()
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        VStack(spacing: 12) {
            ProfileAvatar(icon: selectedIcon, photo: shownPhoto, size: 104)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedIcon)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(shownPhoto != nil ? "Profile photo" : "Profile icon, \(ProfileIconStyle.accessibilityName(for: selectedIcon))")

            Text(displayName.isEmpty ? "Display Name" : displayName)
                .scaledFont(size: 22, weight: .bold, design: .rounded)
                .foregroundStyle(displayName.isEmpty ? Color.lavendar.opacity(0.5) : Color.white)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Photo Actions

    private var photoActions: some View {
        AdaptiveStack(spacing: 10, verticalAlignment: .center, horizontalAlignment: .center) {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                photoActionLabel("Upload", systemImage: "photo.fill")
            }
            .buttonStyle(PressScaleButtonStyle())

            if CameraPicker.isAvailable {
                Button {
                    showCamera = true
                } label: {
                    photoActionLabel("Take Photo", systemImage: "camera.fill")
                }
                .buttonStyle(PressScaleButtonStyle())
            }

            if shownPhoto != nil {
                Button {
                    withAnimation(.snappy) {
                        draftPhoto = nil
                        removesPhoto = true
                    }
                    Haptics.play(.decrease)
                } label: {
                    photoActionLabel("Remove", systemImage: "trash.fill", tint: Color.dreamCoral)
                }
                .buttonStyle(PressScaleButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: shownPhoto != nil)
    }

    private func photoActionLabel(_ title: LocalizedStringKey,
                                  systemImage: String,
                                  tint: Color = Color.lavendar) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay {
                Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1)
            }
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
                ForEach(ProfileIconStyle.icons, id: \.self) { icon in
                    iconButton(icon)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func iconButton(_ icon: String) -> some View {
        let isSelected = selectedIcon == icon && shownPhoto == nil

        return Button {
            Haptics.play(.select)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedIcon = icon
                draftPhoto = nil
                removesPhoto = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(ProfileIconStyle.gradient(for: icon))
                    .frame(height: 60)
                    .overlay {
                        Circle()
                            .strokeBorder(isSelected ? Color.starlightGold : Color.white.opacity(0.2),
                                          lineWidth: isSelected ? 3 : 1)
                    }
                    .shadow(color: isSelected ? Color.starlightGold.opacity(0.45) : .clear, radius: 10)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.starlightGold)
                        .background(Circle().fill(Color.midnightNavy))
                        .offset(x: 18, y: -18)
                }
            }
            .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text(ProfileIconStyle.accessibilityName(for: icon)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Photos

    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                useDraftPhoto(image)
            } else {
                Haptics.play(.error)
            }
            pickerItem = nil
        }
    }

    private func useDraftPhoto(_ image: UIImage) {
        withAnimation(.snappy) {
            draftPhoto = ProfilePhotoStore.squared(image, side: 512)
            removesPhoto = false
        }
        Haptics.play(.photo)
    }

    // MARK: - Save Action

    private func saveProfile() {
        guard isValid else { return }
        savedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        savedIcon = selectedIcon

        if removesPhoto {
            photoStore.remove()
        } else if let draftPhoto {
            photoStore.save(draftPhoto)
        }

        Haptics.play(.success)
        dismiss()
    }
}

#Preview {
    SetupProfileSheetView()
}
