//
//  SettingsStore.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 09.09.2025.
//

import Foundation

/// Default values for app settings stored in UserDefaults.
/// Provides consistent fallback values and template content for AI notifications.
struct AppStorageDefaults {
    /// Default prompt template for AI-generated daily summary notifications.
    /// Contains placeholders for app and website usage data replacement.
    static let summaryNotificationPrompt = """
        Create a concise daily summary notification (100-150 chars max). Use emojis and friendly tone. No markdown formatting.

        Usage overview:
        Apps: {appSummary}
        Sites: {websiteSummary}

        Focus on key insights and productivity patterns. Make it encouraging and actionable.
        """

    /// Default notification time set to 9:00 AM as TimeInterval since epoch.
    /// Used for scheduling daily summary notifications.
    static let summaryNotificationTime: Double = {
        let calendar = Calendar.current
        let components = DateComponents(hour: 9, minute: 0)
        return calendar.date(from: components)?.timeIntervalSince1970 ?? 0
    }()

    /// Default private browsing tracking preference.
    /// Privacy-first approach: disabled by default to protect user privacy.
    static let trackPrivateBrowsing = false

    // MARK: - Tracking Intervals

    /// Default activity polling interval in seconds.
    /// Controls how often the app checks the frontmost application.
    static let trackingInterval: Double = 1.0

    /// Default data persistence interval in seconds.
    /// Controls how often tracked sessions are batch-saved to the database.
    static let dataPersistenceInterval: Double = 30.0

    /// Default idle detection threshold in seconds.
    /// After this many seconds of inactivity, all active sessions are ended.
    static let idleThreshold: Double = 300.0
}

/// Available tracking interval options for the polling timer.
/// Each case represents a selectable interval in seconds.
enum TrackingInterval: Double, CaseIterable, Identifiable {
    case halfSecond = 0.5
    case oneSecond = 1.0
    case twoSeconds = 2.0
    case fiveSeconds = 5.0
    case tenSeconds = 10.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .halfSecond: return "0.5s (High accuracy)"
        case .oneSecond: return "1s (Recommended)"
        case .twoSeconds: return "2s"
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s (Low power)"
        }
    }
}

/// Available data persistence interval options for batch saving.
/// Each case represents a selectable interval in seconds.
enum PersistenceInterval: Double, CaseIterable, Identifiable {
    case tenSeconds = 10.0
    case fifteenSeconds = 15.0
    case thirtySeconds = 30.0
    case sixtySeconds = 60.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .tenSeconds: return "10s (Frequent saves)"
        case .fifteenSeconds: return "15s"
        case .thirtySeconds: return "30s (Recommended)"
        case .sixtySeconds: return "60s (Low I/O)"
        }
    }
}

/// Available idle detection threshold options.
/// Each case represents the number of seconds of inactivity before sessions are ended.
enum IdleThreshold: Double, CaseIterable, Identifiable {
    case oneMinute = 60.0
    case twoMinutes = 120.0
    case threeMinutes = 180.0
    case fiveMinutes = 300.0
    case tenMinutes = 600.0
    case fifteenMinutes = 900.0
    case thirtyMinutes = 1800.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .twoMinutes: return "2 minutes"
        case .threeMinutes: return "3 minutes"
        case .fiveMinutes: return "5 minutes (Recommended)"
        case .tenMinutes: return "10 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        }
    }
}

/// UserDefaults extension providing environment-specific storage isolation.
/// Debug builds use separate settings to avoid conflicts with release versions.
extension UserDefaults {
    static let app: UserDefaults = {
        #if DEBUG
            let bundleId = Bundle.main.bundleIdentifier!
            return UserDefaults(suiteName: "\(bundleId).debug") ?? UserDefaults.standard
        #else
            return UserDefaults.standard
        #endif
    }()
}
