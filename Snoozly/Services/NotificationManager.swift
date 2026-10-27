//
//  NotificationManager.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-14.
//

import Foundation
import UIKit
import UserNotifications
import os

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "com.dantedabramo.Snoozly", category: "Notifications")

    private enum Kind: String, CaseIterable {
        case windDown
        case bedtime
    }

    private static func identifier(_ kind: Kind, _ day: Weekday) -> String {
        "snoozly.\(kind.rawValue).\(day.rawValue)"
    }

    private static var allIdentifiers: [String] {
        Weekday.allCases.flatMap { day in
            Kind.allCases.map { NotificationManager.identifier($0, day) }
        }
    }

    // MARK: - Setup

    func registerAsDelegate() {
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // MARK: - Permission

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("Authorization request failed: \(error.localizedDescription)")
            return false
        }
    }

    private func isAuthorized() async -> Bool {
        await access() == .allowed
    }

    enum Access {
        case allowed
        case denied
        case notDetermined
    }

    func access() async -> Access {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    @discardableResult
    func turnOnReminders(for plan: SleepPlan) async -> Access {
        let before = await access()

        switch before {
        case .allowed:
            plan.notificationsEnabled = true
            return .allowed
        case .notDetermined:
            let granted = await requestAuthorization()
            plan.notificationsEnabled = granted
            return granted ? .allowed : .denied
        case .denied:
            plan.notificationsEnabled = false
            if let url = URL(string: UIApplication.openSettingsURLString) {
                _ = await UIApplication.shared.open(url)
            }
            return .denied
        }
    }

    // MARK: - Scheduling

    func reschedule(for plan: SleepPlan) async {
        guard plan.notificationsEnabled, await isAuthorized() else {
            center.removePendingNotificationRequests(withIdentifiers: NotificationManager.allIdentifiers)
            return
        }

        let requests = makeRequests(for: plan)
        let kept = Set(requests.map(\.identifier))
        center.removePendingNotificationRequests(
            withIdentifiers: NotificationManager.allIdentifiers.filter { !kept.contains($0) }
        )

        for request in requests {
            do {
                try await center.add(request)
            } catch {
                log.error("Could not schedule \(request.identifier): \(error.localizedDescription)")
            }
        }
    }

    private func makeRequests(for plan: SleepPlan) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        for night in plan.sortedNights where night.isEnabled {
            let bedtimeText = night.bedtimeMinutes.clockText

            requests.append(makeRequest(
                .windDown,
                day: night.weekday,
                minutes: night.bedtimeMinutes - plan.windDownMinutes,
                title: String(localized: "Time to wind down"),
                body: String(localized: "Bedtime is at \(bedtimeText). Let's slow things down.")
            ))

            requests.append(makeRequest(
                .bedtime,
                day: night.weekday,
                minutes: night.bedtimeMinutes,
                title: String(localized: "Bedtime"),
                body: String(localized: "Sweet dreams. It's time to head to bed.")
            ))
        }

        return requests
    }

    private func makeRequest(_ kind: Kind,
                             day: Weekday,
                             minutes: Int,
                             title: String,
                             body: String) -> UNNotificationRequest {
        let dayShift = minutes < 0 ? -1 : 0
        let wrapped = ((minutes % (24 * 60)) + 24 * 60) % (24 * 60)

        var when = DateComponents()
        when.weekday = day.shifted(by: dayShift).calendarWeekday
        when.hour = wrapped / 60
        when.minute = wrapped % 60

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        return UNNotificationRequest(
            identifier: NotificationManager.identifier(kind, day),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        )
    }
}
