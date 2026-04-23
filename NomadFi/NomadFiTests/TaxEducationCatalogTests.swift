// TaxEducationCatalogTests.swift
// NomadFi
//
// Pure coverage for the Phase 7A starter catalogue. Everything is
// locally authored — the catalog is a static namespace — so tests
// run in parallel without a ModelContainer.
//
// Pins the product contract:
//   • Starter scope covers exactly the three mission regions
//     (US / CA / TT) in this slice.
//   • Every lesson carries at least one official-source citation.
//   • Every checklist has a non-empty item list and an escalation
//     note.
//   • No lesson, checklist, reason, or disclaimer uses banned
//     tax-advice phrasing.

import Foundation
import Testing

@testable import NomadFi

struct TaxEducationCatalogTests {

    // MARK: - Starter scope

    @Test("Supported regions are exactly the three mission regions for this slice")
    func supportedRegionsMatchesStarterScope() {
        let regions = Set(TaxEducationCatalog.supportedRegions)
        #expect(regions == Set([
            TaxEducationRegion.unitedStates,
            TaxEducationRegion.canada,
            TaxEducationRegion.trinidadAndTobago,
        ]))
    }

    @Test("Every supported region ships at least two starter lessons")
    func minimumLessonCountPerRegion() {
        for region in TaxEducationCatalog.supportedRegions {
            let lessons = TaxEducationCatalog.lessons(for: region)
            #expect(
                lessons.count >= 2,
                "\(region.displayName) should ship at least two starter lessons."
            )
        }
    }

    @Test("Every supported region ships exactly one starter checklist with non-empty items")
    func checklistShape() {
        for region in TaxEducationCatalog.supportedRegions {
            let checklist = TaxEducationCatalog.checklist(for: region)
            #expect(checklist.region == region)
            #expect(!checklist.title.isEmpty)
            #expect(!checklist.items.isEmpty)
            #expect(!checklist.escalationNote.isEmpty)
        }
    }

    // MARK: - Source backing

    @Test("Every starter lesson carries at least one official-source citation")
    func everyLessonHasOfficialSource() {
        for region in TaxEducationCatalog.supportedRegions {
            for lesson in TaxEducationCatalog.lessons(for: region) {
                #expect(
                    !lesson.sources.isEmpty,
                    "Lesson \(lesson.id) must cite at least one official source."
                )
                for source in lesson.sources {
                    #expect(!source.publisher.isEmpty)
                    #expect(!source.title.isEmpty)
                    // URL can't be empty — URL(string: "")! would
                    // have crashed at init time, but we still
                    // check the absoluteString is non-trivial.
                    #expect(!source.url.absoluteString.isEmpty)
                }
            }
        }
    }

    @Test("Every exposed lesson passes the catalogue's own validator")
    func everyLessonIsValid() {
        for region in TaxEducationCatalog.supportedRegions {
            for lesson in TaxEducationCatalog.lessons(for: region) {
                #expect(
                    TaxEducationCatalog.isValid(lesson),
                    "Lesson \(lesson.id) failed catalogue validation."
                )
            }
        }
    }

    // MARK: - Lesson shape

    @Test("Each lesson has a complete title, what-it-is, why-it-matters, and at least one review prompt")
    func lessonShapeComplete() {
        for region in TaxEducationCatalog.supportedRegions {
            for lesson in TaxEducationCatalog.lessons(for: region) {
                #expect(!lesson.title.isEmpty, "\(lesson.id) has empty title")
                #expect(!lesson.whatItIs.isEmpty, "\(lesson.id) has empty whatItIs")
                #expect(!lesson.whyItMatters.isEmpty, "\(lesson.id) has empty whyItMatters")
                #expect(!lesson.whatToReviewNext.isEmpty, "\(lesson.id) has no review prompts")
                #expect(lesson.region == region)
            }
        }
    }

    @Test("Lesson ids are globally unique across the catalogue")
    func lessonIdsAreGloballyUnique() {
        var seen = Set<String>()
        for region in TaxEducationCatalog.supportedRegions {
            for lesson in TaxEducationCatalog.lessons(for: region) {
                #expect(seen.insert(lesson.id).inserted, "Duplicate lesson id: \(lesson.id)")
            }
        }
    }

    // MARK: - Copy guard

    @Test("No lesson, checklist, source summary, or escalation note uses banned tax-advice phrasing")
    func copyGuardOnCatalogVocabulary() {
        let bannedPhrases: [String] = [
            "you should file",
            "you qualify",
            "this is deductible",
            "guaranteed",
            // "approved" — scanned with word-boundary below to avoid
            // catching "approve" inside benign contexts. We use a
            // strict substring here since no starter copy uses it.
            "approved",
            "tax advice",
            "legal advice",
            "immigration advice",
        ]

        var inspected: [String] = []
        for region in TaxEducationCatalog.supportedRegions {
            let checklist = TaxEducationCatalog.checklist(for: region)
            inspected.append(checklist.title)
            inspected.append(checklist.escalationNote)
            for item in checklist.items {
                inspected.append(item.text)
            }

            for lesson in TaxEducationCatalog.lessons(for: region) {
                inspected.append(lesson.title)
                inspected.append(lesson.whatItIs)
                inspected.append(lesson.whyItMatters)
                for prompt in lesson.whatToReviewNext {
                    inspected.append(prompt)
                }
                if let escalation = lesson.escalationNote {
                    inspected.append(escalation)
                }
                for source in lesson.sources {
                    inspected.append(source.title)
                    inspected.append(source.summary)
                    inspected.append(source.publisher)
                }
            }
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in education copy: \(copy)"
                )
            }
        }
    }
}
