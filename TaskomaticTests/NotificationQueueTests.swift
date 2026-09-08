import UserNotifications
import XCTest

@testable import Taskomatic

@MainActor
final class NotificationQueueTests: XCTestCase {
  func testInterruptedRenewalPreservesExistingReserveAndRetryConverges() async throws {
    let initial = (0..<60).map { request("taskomatic.date-\($0)") }
    let queue = MemoryNotificationQueue(initial)
    let desired = (1...60).map { request("taskomatic.date-\($0)") }
    var renewal: Task<Void, Error>!
    queue.afterAdd = { if queue.additions == 2 { renewal.cancel() } }
    renewal = Task { try await NotificationReconciler.replace(desired, in: queue) }
    do {
      try await renewal.value
      XCTFail("An interrupted renewal must report cancellation")
    } catch is CancellationError {} catch { throw error }
    XCTAssertGreaterThanOrEqual(queue.requests.count, 60)
    XCTAssertNotNil(queue.requests["taskomatic.date-59"])

    queue.afterAdd = nil
    try await NotificationReconciler.replace(desired, in: queue)
    XCTAssertEqual(Set(queue.requests.keys), Set(desired.map(\.identifier)))
  }

  func testChangingEveryReminderRespectsCapacityAndPreservesPreview() async throws {
    let initial = (0..<60).map { request("taskomatic.old-\($0)") }
    let queue = MemoryNotificationQueue(initial + [request("taskomatic.test")])
    let desired = (0..<60).map { request("taskomatic.new-\($0)") }
    try await NotificationReconciler.replace(desired, in: queue)
    XCTAssertLessThanOrEqual(queue.peakCount, 64)
    XCTAssertEqual(Set(queue.requests.keys), Set(desired.map(\.identifier) + ["taskomatic.test"]))
    try await NotificationReconciler.replace([], in: queue)
    XCTAssertEqual(Set(queue.requests.keys), ["taskomatic.test"])
  }

  private func request(_ id: String) -> UNNotificationRequest {
    UNNotificationRequest(identifier: id, content: UNMutableNotificationContent(), trigger: nil)
  }
}

@MainActor
private final class MemoryNotificationQueue: PendingNotificationQueue {
  var requests: [String: UNNotificationRequest]
  var additions = 0
  var peakCount: Int
  var afterAdd: (() -> Void)?

  init(_ requests: [UNNotificationRequest]) {
    self.requests = Dictionary(uniqueKeysWithValues: requests.map { ($0.identifier, $0) })
    peakCount = requests.count
  }

  func pending() async -> [UNNotificationRequest] { Array(requests.values) }
  func add(_ request: UNNotificationRequest) async throws {
    requests[request.identifier] = request
    additions += 1
    peakCount = max(peakCount, requests.count)
    afterAdd?()
  }
  func remove(_ identifiers: [String]) { for id in identifiers { requests[id] = nil } }
}
