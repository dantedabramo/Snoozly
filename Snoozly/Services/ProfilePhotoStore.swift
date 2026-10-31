//
//  ProfilePhotoStore.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-29.
//

import SwiftUI
import UIKit

// MARK: - ProfilePhotoStore

@Observable
@MainActor
final class ProfilePhotoStore {
    static let shared = ProfilePhotoStore()

    private(set) var image: UIImage?

    @ObservationIgnored private let maxDimension: CGFloat = 512

    private var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "ProfilePhoto.jpg")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL) {
            image = UIImage(data: data)
        }
    }

    func save(_ original: UIImage) {
        let prepared = Self.squared(original, side: maxDimension)

        guard let data = prepared.jpegData(compressionQuality: 0.85) else { return }

        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory,
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
        image = prepared
    }

    func remove() {
        try? FileManager.default.removeItem(at: fileURL)
        image = nil
    }

    static func squared(_ source: UIImage, side: CGFloat) -> UIImage {
        let size = source.size
        let shortest = min(size.width, size.height)
        let target = min(side, shortest)

        guard shortest > 0 else { return source }

        let scale = target / shortest
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (target - drawSize.width) / 2, y: (target - drawSize.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)

        return renderer.image { _ in
            source.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
