import Foundation
import SwiftUI
import Combine
import AppKit

enum RefreshInterval: Int, CaseIterable, Sendable {
    case twoMinutes = 120
    case threeMinutes = 180
    case fiveMinutes = 300
    case tenMinutes = 600

    var label: String {
        switch self {
        case .twoMinutes: return "2 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        case .tenMinutes: return "10 min"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }
}

enum ResetSound: String, CaseIterable, Sendable {
    case none = "none"
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case tink = "Tink"

    var label: String {
        switch self {
        case .none: return "Off"
        case .glass: return "Glass"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .purr: return "Purr"
        case .sosumi: return "Sosumi"
        case .tink: return "Tink"
        }
    }

    func play() {
        guard self != .none else { return }
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}

/// User preferences for the app.
/// Thread-safe through the use of UserDefaults (which is thread-safe)
/// and @Published for UI updates on main thread.
final class UserSettings: ObservableObject, @unchecked Sendable {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard
    private let refreshIntervalKey = "refreshInterval"
    private let resetSoundKey = "resetSound"

    @Published var refreshIntervalRaw: Int {
        didSet {
            defaults.set(refreshIntervalRaw, forKey: refreshIntervalKey)
        }
    }

    @Published var resetSoundRaw: String {
        didSet {
            defaults.set(resetSoundRaw, forKey: resetSoundKey)
        }
    }

    var refreshInterval: RefreshInterval {
        get { RefreshInterval(rawValue: refreshIntervalRaw) ?? .fiveMinutes }
        set { refreshIntervalRaw = newValue.rawValue }
    }

    var resetSound: ResetSound {
        get { ResetSound(rawValue: resetSoundRaw) ?? .none }
        set { resetSoundRaw = newValue.rawValue }
    }

    private init() {
        let storedInterval = defaults.integer(forKey: refreshIntervalKey)
        let needsMigration: Bool
        if storedInterval == 0 {
            self.refreshIntervalRaw = RefreshInterval.fiveMinutes.rawValue
            needsMigration = false
        } else if storedInterval == 30 || storedInterval == 60 {
            // Migrate removed 30s/1min intervals to 2min
            self.refreshIntervalRaw = RefreshInterval.twoMinutes.rawValue
            needsMigration = true
        } else {
            self.refreshIntervalRaw = storedInterval
            needsMigration = false
        }

        let storedSound = defaults.string(forKey: resetSoundKey)
        self.resetSoundRaw = storedSound ?? ResetSound.none.rawValue

        // Persist migration after all stored properties are initialized
        if needsMigration {
            defaults.set(refreshIntervalRaw, forKey: refreshIntervalKey)
        }
    }
}
