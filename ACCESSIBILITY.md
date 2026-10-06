# Accessibility

NomadFi is an iOS personal-finance app built with SwiftUI.

## Current implementation

The [shared accessibility components](NomadFi/NomadFi/DesignSystem/Components/AccessibilityModifiers.swift)
provide animation that respects Reduce Motion and status cues for
Differentiate Without Color. Content sits on solid surfaces; navigation
bars, tab bars and sheets use the system's Liquid Glass, which handles
Reduce Transparency itself.

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

## Public statement and reporting

The public [accessibility statement](https://arieltyson.github.io/nomadfi-accessibility/)
and [known issues](https://arieltyson.github.io/nomadfi-accessibility/known-issues/)
live in [arieltyson/nomadfi-accessibility](https://github.com/arieltyson/nomadfi-accessibility),
which is where to [report an accessibility barrier](https://github.com/arieltyson/nomadfi-accessibility/issues/new?template=accessibility-barrier.yml).
Describe the task, what stopped you, your device, the iOS and app
versions, and any assistive technology or settings involved. Keep that
statement in step with this file when features or verification change.
