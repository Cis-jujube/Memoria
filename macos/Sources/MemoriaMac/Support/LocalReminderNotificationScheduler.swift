import Foundation
import MemoriaCore
@preconcurrency import UserNotifications

struct LocalReminderNotificationScheduler {
    func sync(
        plans: [ReminderNotificationPlan],
        enabled: Bool,
        completion: @escaping @Sendable (Result<Int, Error>) -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        let identifiers = plans.map(\.identifier)

        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            completion(.success(0))
            return
        }

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard granted else {
                completion(.success(0))
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            for plan in plans {
                let content = UNMutableNotificationContent()
                content.title = plan.title
                content.body = plan.body.isEmpty ? plan.dueLabel : plan.body
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: plan.identifier,
                    content: content,
                    trigger: trigger(for: plan)
                )
                center.add(request)
            }
            completion(.success(plans.count))
        }
    }

    private func trigger(for plan: ReminderNotificationPlan) -> UNNotificationTrigger {
        let parts = plan.timeLabel.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else {
            return UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts[0]
        components.minute = parts[1]

        if let date = Calendar.current.date(from: components),
           date > Date() {
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        return UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
    }
}
