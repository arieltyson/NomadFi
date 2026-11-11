// OnboardingPreferences.swift
// NomadFi
//
// The one key that decides whether NomadFi opens on onboarding.

import Foundation

/// Where the app records that onboarding is finished. Shared by the app's
/// `@AppStorage` and by Delete All My Data, which resets it.
enum OnboardingPreferences {
    static let completedKey = "hasCompletedOnboarding"
}
