import Foundation
import UserNotifications
import CoreData
import UIKit

/// Manages local notifications for event reminders
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingNotificationsCount: Int = 0

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        Task {
            await refreshAuthorizationStatus()
            await updatePendingCount()
        }
    }

    // MARK: - Authorization

    /// Request notification authorization from the user
    /// - Returns: Whether authorization was granted
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    /// Refresh the current authorization status
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Check if notifications are authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    /// Check if we need to request authorization (not determined yet)
    var needsAuthorizationRequest: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - Schedule Notifications

    /// Schedule a notification for an event
    /// - Parameter event: The event to schedule a notification for
    func scheduleNotification(for event: Event) async {
        guard let eventId = event.id,
              let eventDate = event.date,
              let offset = event.reminderOffsetValue else {
            return
        }

        // Calculate reminder date
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -offset.days, to: eventDate) else {
            return
        }

        // Don't schedule notifications for past dates
        if reminderDate < Date() {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()

        let eventType = event.eventTypeValue
        let title = event.title ?? "Event"
        let personName = event.lovedOne?.name

        if eventType == .birthday {
            content.title = "Upcoming Birthday: \(personName ?? "Someone special")"
            content.body = buildBirthdayBody(title: title, personName: personName, offset: offset)
        } else {
            content.title = "Reminder: \(title)"
            content.body = buildEventBody(title: title, offset: offset)
        }

        content.sound = .default
        content.badge = NSNumber(value: 1)

        // Add category for actionable notifications
        content.categoryIdentifier = "EVENT_REMINDER"

        // Add user info for handling notification response
        content.userInfo = [
            "eventId": eventId.uuidString,
            "eventType": eventType.rawValue,
            "isBirthday": eventType == .birthday
        ]

        // Create trigger based on reminder date
        var dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )

        // For all-day events, set notification to 9 AM
        if event.isAllDay {
            dateComponents.hour = 9
            dateComponents.minute = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Create request with event-based identifier
        let identifier = notificationIdentifier(for: event)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule the notification
        do {
            try await center.add(request)
            await updatePendingCount()
            print("Scheduled notification for event: \(title) at \(reminderDate)")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    /// Schedule a birthday notification for the next year
    /// - Parameters:
    ///   - event: The birthday event
    ///   - year: The year to schedule for
    func scheduleBirthdayForNextYear(event: Event, currentYear: Int) async {
        guard let eventId = event.id,
              let eventDate = event.date,
              let offset = event.reminderOffsetValue,
              event.eventTypeValue == .birthday else {
            return
        }

        let calendar = Calendar.current

        // Calculate next year's date
        var components = calendar.dateComponents([.month, .day], from: eventDate)
        components.year = currentYear + 1

        guard let nextYearDate = calendar.date(from: components),
              let reminderDate = calendar.date(byAdding: .day, value: -offset.days, to: nextYearDate) else {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        let personName = event.lovedOne?.name ?? "Someone special"

        content.title = "Upcoming Birthday: \(personName)"
        content.body = buildBirthdayBody(title: event.title ?? "", personName: personName, offset: offset)
        content.sound = .default
        content.badge = NSNumber(value: 1)
        content.categoryIdentifier = "EVENT_REMINDER"
        content.userInfo = [
            "eventId": eventId.uuidString,
            "eventType": EventType.birthday.rawValue,
            "isBirthday": true,
            "year": currentYear + 1
        ]

        // Create trigger
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Create request with year-specific identifier for birthdays
        let identifier = "birthday_\(eventId.uuidString)_\(currentYear + 1)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            await updatePendingCount()
            print("Scheduled next year birthday notification for: \(personName)")
        } catch {
            print("Failed to schedule next year birthday: \(error)")
        }
    }

    // MARK: - Cancel Notifications

    /// Cancel notification for an event
    /// - Parameter event: The event to cancel notifications for
    func cancelNotification(for event: Event) {
        let identifier = notificationIdentifier(for: event)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Also cancel any birthday-specific notifications
        if event.eventTypeValue == .birthday, let eventId = event.id {
            let currentYear = Calendar.current.component(.year, from: Date())
            let birthdayIdentifiers = (currentYear...(currentYear + 5)).map {
                "birthday_\(eventId.uuidString)_\($0)"
            }
            center.removePendingNotificationRequests(withIdentifiers: birthdayIdentifiers)
        }

        Task {
            await updatePendingCount()
        }
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        Task {
            await updatePendingCount()
        }
    }

    // MARK: - Helpers

    /// Update the count of pending notifications
    func updatePendingCount() async {
        let requests = await center.pendingNotificationRequests()
        pendingNotificationsCount = requests.count
    }

    /// Generate notification identifier for an event
    private func notificationIdentifier(for event: Event) -> String {
        guard let eventId = event.id else {
            return UUID().uuidString
        }
        return "event_\(eventId.uuidString)"
    }

    /// Build body text for birthday notifications
    private func buildBirthdayBody(title: String, personName: String?, offset: ReminderOffset) -> String {
        let name = personName ?? "Someone special"

        switch offset {
        case .sameDay:
            return "\(name)'s Birthday is today!"
        case .oneDay:
            return "\(name)'s Birthday is tomorrow"
        case .twoDays:
            return "\(name)'s Birthday is in 2 days"
        case .threeDays:
            return "\(name)'s Birthday is in 3 days"
        case .oneWeek:
            return "\(name)'s Birthday is in one week"
        }
    }

    /// Build body text for general event notifications
    private func buildEventBody(title: String, offset: ReminderOffset) -> String {
        switch offset {
        case .sameDay:
            return "\(title) is today!"
        case .oneDay:
            return "\(title) is tomorrow"
        case .twoDays:
            return "\(title) is in 2 days"
        case .threeDays:
            return "\(title) is in 3 days"
        case .oneWeek:
            return "\(title) is in one week"
        }
    }

    // MARK: - Notification Categories

    /// Setup notification categories for actionable notifications
    func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_EVENT",
            title: "View Event",
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )

        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([eventCategory])
    }

    // MARK: - Badge Management

    /// Clear the app badge
    func clearBadge() {
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    /// Open system settings for this app
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    /// Handle notification response (tap)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Handle birthday rescheduling
        if let isBirthday = userInfo["isBirthday"] as? Bool,
           isBirthday,
           let eventIdString = userInfo["eventId"] as? String,
           let currentYear = userInfo["year"] as? Int {

            // Post notification to reschedule birthday for next year
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .reschedulebirthday,
                    object: nil,
                    userInfo: [
                        "eventId": eventIdString,
                        "year": currentYear
                    ]
                )
            }
        }

        // Handle action based on identifier
        switch response.actionIdentifier {
        case "VIEW_EVENT":
            if let eventIdString = userInfo["eventId"] as? String {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .openEvent,
                        object: nil,
                        userInfo: ["eventId": eventIdString]
                    )
                }
            }
        case "DISMISS", UNNotificationDefaultActionIdentifier, UNNotificationDismissActionIdentifier:
            break
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let reschedulebirthday = Notification.Name("reschedulebirthday")
    static let openEvent = Notification.Name("openEvent")
}
