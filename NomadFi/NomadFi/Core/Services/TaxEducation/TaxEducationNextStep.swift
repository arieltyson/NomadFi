// TaxEducationNextStep.swift
// NomadFi
//
// Deterministic "Next to review" pointer surfaced near the top of
// each region block. `nil` when the user has already marked every
// lesson and every checklist item completed — the UI then hides
// the callout entirely rather than inventing a new step.

import Foundation

struct TaxEducationNextStep: Sendable, Equatable, Identifiable {

    /// Stable identifier: `"lesson-\(region)-\(lessonID)"`,
    /// `"checklist-\(region)-\(itemID)"`, or
    /// `"quiz-\(region)-\(quizID)"`.
    let id: String

    let region: TaxEducationRegion
    let kind: TaxEducationProgressKind

    /// Short title for the card (lesson title, checklist item
    /// text, or quiz title).
    let title: String

    /// Optional supporting caption. Used for a lesson's
    /// `whatItIs` one-liner, the quiz's summary, or empty for
    /// checklist items.
    let subtitle: String

    /// For lesson next-steps, the underlying lesson id so the UI
    /// can open the detail sheet directly. Empty for checklist
    /// items and quizzes.
    let lessonID: String

    /// For checklist next-steps, the underlying item id so the UI
    /// can highlight / scroll to the right row. Empty for lessons
    /// and quizzes.
    let checklistItemID: String

    /// For quiz next-steps, the quiz id so the UI can open the
    /// right quiz sheet directly. Empty for lessons and checklist
    /// items.
    let quizID: String

    init(
        id: String,
        region: TaxEducationRegion,
        kind: TaxEducationProgressKind,
        title: String,
        subtitle: String,
        lessonID: String = "",
        checklistItemID: String = "",
        quizID: String = ""
    ) {
        self.id = id
        self.region = region
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.lessonID = lessonID
        self.checklistItemID = checklistItemID
        self.quizID = quizID
    }
}
