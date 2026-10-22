import Foundation
import SwiftData

/// Single source of truth for the user's body measurements. Always yields a profile
/// (empty until the user fills it in), so callers only need to nil-check the fields.
@MainActor
final class UserProfileRepository {
    static let maxWeightKg = 500.0
    static let maxHeightCm = 300.0

    /// Missing, non-positive or non-finite input means "not set"; anything else is capped at `max`.
    nonisolated static func sanitize(_ value: Double?, max: Double) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return Swift.min(value, max)
    }

    private unowned let store: DataStore

    init(store: DataStore) {
        self.store = store
    }

    func profile() -> UserProfile {
        guard let model = model() else { return UserProfile() }
        return UserProfile(
            weightKg: model.weightKg,
            heightCm: model.heightCm,
            gender: model.genderRaw.flatMap(Gender.init(rawValue:))
        )
    }

    /// One-shot read, for writes that need the current value (e.g. body-weight exercises).
    func bodyWeightKg() -> Double? { profile().weightKg }

    func updateProfile(weightKg: Double?, heightCm: Double?, gender: Gender?) {
        let weight = Self.sanitize(weightKg, max: Self.maxWeightKg)
        let height = Self.sanitize(heightCm, max: Self.maxHeightCm)
        if let existing = model() {
            existing.weightKg = weight
            existing.heightCm = height
            existing.genderRaw = gender?.rawValue
        } else {
            store.context.insert(UserProfileModel(weightKg: weight, heightCm: height, genderRaw: gender?.rawValue))
        }
        store.commit()
    }

    private func model() -> UserProfileModel? {
        let singleton = UserProfileModel.singletonId
        var descriptor = FetchDescriptor<UserProfileModel>(predicate: #Predicate { $0.id == singleton })
        descriptor.fetchLimit = 1
        return (try? store.context.fetch(descriptor))?.first
    }
}
