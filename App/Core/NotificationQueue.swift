import Foundation
@preconcurrency import UserNotifications

/// The system notification queue is the only delivery boundary used by reconciliation.
@MainActor
protocol PendingNotificationQueue {
  func pending() async -> [UNNotificationRequest]
  func add(_ request: UNNotificationRequest) async throws
  func remove(_ identifiers: [String])
}

@MainActor
struct SystemNotificationQueue: PendingNotificationQueue {
  let center: UNUserNotificationCenter

  func pending() async -> [UNNotificationRequest] {
    await center.pendingNotificationRequests()
  }

  func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }

  func remove(_ identifiers: [String]) {
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }
}

@MainActor
enum NotificationReconciler {
  static func replace(_ desired: [UNNotificationRequest], in queue: any PendingNotificationQueue)
    async throws
  {
    try Task.checkCancellation()
    let pending = await queue.pending()
    try Task.checkCancellation()
    let wanted = Set(desired.map(\.identifier))
    var current = Set(pending.filter { owns($0.identifier) }.map(\.identifier))
    var obsolete = current.subtracting(wanted).sorted()
    // Reserve one slot for the preview notification. Never clear a working reserve
    // before replacements exist: iOS may expire background execution at any await.
    let foreignCount = pending.filter { !owns($0.identifier) }.count
    let capacity = 64 - max(1, foreignCount)
    for request in desired {
      try Task.checkCancellation()
      if !current.contains(request.identifier), current.count >= capacity {
        guard !obsolete.isEmpty else { throw QueueError.capacityExceeded }
        let removed = obsolete.removeFirst()
        queue.remove([removed])
        current.remove(removed)
      }
      try await queue.add(request)
      current.insert(request.identifier)
    }
    try Task.checkCancellation()
    queue.remove(obsolete)
  }

  private enum QueueError: Error { case capacityExceeded }

  private static func owns(_ identifier: String) -> Bool {
    identifier.hasPrefix("taskomatic.") && identifier != "taskomatic.test"
  }
}
