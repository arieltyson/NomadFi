# Accessibility

NomadFi is an iOS personal-finance app built with SwiftUI.

## Current implementation

The [shared accessibility components](NomadFi/NomadFi/DesignSystem/Components/AccessibilityModifiers.swift)
provide animation that respects Reduce Motion, layouts that switch to a
vertical arrangement at accessibility text sizes, Reduce Transparency
handling, and status cues for Differentiate Without Color.

[Contrast regression tests](NomadFi/NomadFiTests/AccessibilityContrastComplianceTests.swift)
cover selected brand and action-colour combinations in light and dark
appearance. Their scope is the specified colour pairs, not every rendered
screen or system presentation.

## Validation and limitations

Shared components and colour tests do not establish full app conformance.
Validate each finance workflow with VoiceOver, Voice Control, the largest
text sizes, and the relevant display settings. Include spoken amounts and
currencies, charts, forms, authentication, import errors, and any external
service or system screens encountered in the task.

This statement documents implementation and test scope; it does not claim
that all assistive-technology task checks have passed.

## Report an accessibility problem

[Open an issue](https://github.com/arieltyson/NomadFi/issues/new) describing
the affected screen, steps to reproduce, expected and actual behaviour,
and the app version or commit. Include your device, iOS version, and
relevant assistive technology or accessibility settings.
