import Foundation

/// Manages PureScan's happy-path review gate:
/// - Waits until the user completes their 2nd scan so they've experienced real value.
/// - Asks gently ("Enjoying PureScan?") before invoking Apple's native `requestReview()`.
/// - Routes constructive feedback to email (`mailto:a3152557994@gmail.com?subject=PureScan%20Feedback`).
/// - Strictly throttled to at most once every 90 days (100% local UserDefaults, zero telemetry).
final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    static let minimumScansRequired = 2
    static let throttleInterval: TimeInterval = 90 * 24 * 60 * 60 // 90 days
    static let feedbackURL = URL(string: "mailto:a3152557994@gmail.com?subject=PureScan%20Feedback")!

    private let defaults: UserDefaults
    private let lastPromptTimestampKey = "purescan.review.lastPromptAt"
    private let lastActionKey = "purescan.review.lastAction"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns true if the happy-path review gate should appear on the inspection report.
    func shouldShowReviewGate(
        completedScans: Int,
        now: Date = Date(),
        isDemoLaunch: Bool = ProcessInfo.processInfo.arguments.contains("-ui_demo_screen")
    ) -> Bool {
        guard !isDemoLaunch else { return false }
        guard completedScans >= Self.minimumScansRequired else { return false }

        let lastTs = defaults.double(forKey: lastPromptTimestampKey)
        if lastTs > 0 {
            let elapsed = now.timeIntervalSince1970 - lastTs
            if elapsed < Self.throttleInterval {
                return false
            }
        }
        return true
    }

    func recordPositiveReviewTapped(now: Date = Date()) {
        markThrottled(action: "positive", now: now)
        FunnelMetrics.shared.record(.reviewGatePositive)
    }

    func recordFeedbackTapped(now: Date = Date()) {
        markThrottled(action: "feedback", now: now)
        FunnelMetrics.shared.record(.reviewGateFeedback)
    }

    func recordDismissed(now: Date = Date()) {
        markThrottled(action: "dismissed", now: now)
        FunnelMetrics.shared.record(.reviewGateDismissed)
    }

    private func markThrottled(action: String, now: Date) {
        defaults.set(now.timeIntervalSince1970, forKey: lastPromptTimestampKey)
        defaults.set(action, forKey: lastActionKey)
    }

    func reset() {
        defaults.removeObject(forKey: lastPromptTimestampKey)
        defaults.removeObject(forKey: lastActionKey)
    }
}
