//
//  ProfileAvatar.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-29.
//

import SwiftUI
import UIKit

// MARK: - ProfileIconStyle

enum ProfileIconStyle {
    static let icons = [
        "moon.stars.fill",
        "sparkles",
        "bed.double.fill",
        "hare.fill",
        "tortoise.fill",
        "cat.fill",
        "bird.fill",
        "zzz"
    ]

    static func gradient(for icon: String) -> LinearGradient {
        switch icon {
        case "moon.stars.fill":
            gradient(rgb(0.36, 0.31, 0.88), rgb(0.62, 0.38, 0.95), from: .topLeading, to: .bottomTrailing)
        case "sparkles":
            gradient(rgb(0.98, 0.72, 0.22), rgb(0.95, 0.38, 0.45), from: .top, to: .bottom)
        case "bed.double.fill":
            gradient(rgb(0.20, 0.45, 0.95), rgb(0.18, 0.78, 0.82), from: .leading, to: .trailing)
        case "hare.fill":
            gradient(rgb(0.99, 0.45, 0.55), rgb(0.99, 0.70, 0.30), from: .bottomLeading, to: .topTrailing)
        case "tortoise.fill":
            gradient(rgb(0.22, 0.72, 0.48), rgb(0.12, 0.52, 0.62), from: .topTrailing, to: .bottomLeading)
        case "cat.fill":
            gradient(rgb(0.80, 0.58, 0.98), rgb(0.98, 0.58, 0.82), from: .topLeading, to: .bottom)
        case "bird.fill":
            gradient(rgb(0.35, 0.78, 0.98), rgb(0.40, 0.38, 0.92), from: .bottomLeading, to: .topTrailing)
        case "zzz":
            gradient(rgb(0.30, 0.20, 0.62), rgb(0.12, 0.28, 0.58), from: .top, to: .bottomTrailing)
        default:
            gradient(rgb(0.36, 0.31, 0.88), rgb(0.62, 0.38, 0.95), from: .topLeading, to: .bottomTrailing)
        }
    }

    static func accessibilityName(for icon: String) -> String {
        switch icon {
        case "moon.stars.fill": "Moon and stars"
        case "sparkles": "Sparkles"
        case "bed.double.fill": "Bed"
        case "hare.fill": "Hare"
        case "tortoise.fill": "Tortoise"
        case "cat.fill": "Cat"
        case "bird.fill": "Bird"
        case "zzz": "Sleeping"
        default: "Icon"
        }
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }

    private static func gradient(_ first: Color,
                                 _ second: Color,
                                 from start: UnitPoint,
                                 to end: UnitPoint) -> LinearGradient {
        LinearGradient(colors: [first, second], startPoint: start, endPoint: end)
    }
}

// MARK: - ProfileAvatar

struct ProfileAvatar: View {
    let icon: String
    var photo: UIImage? = nil
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(ProfileIconStyle.gradient(for: icon))
                    .frame(width: size, height: size)

                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1)
            }
        }
        .overlay {
            Circle().strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                               startPoint: .top,
                               endPoint: .bottom),
                lineWidth: 1.5
            )
        }
        .shadow(color: Color.dreamPurple.opacity(0.5), radius: size * 0.2)
        .accessibilityHidden(true)
    }
}

// MARK: - CameraPicker

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
