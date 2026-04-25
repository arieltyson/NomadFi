// InvestingEducationCatalogTests.swift
// NomadFi
//
// Pure coverage for the Phase 8A investing-education starter
// catalogue. Locally authored; no `ModelContainer` required.
//
// Pins the product contract:
//   • Starter scope covers exactly the two mission regions the
//     primary-source bar is met for (US + CA). Trinidad and Tobago
//     is intentionally deferred — see
//     `docs/research/InvestingEducationSourceMap.md`.
//   • Every lesson cites at least one official-source citation —
//     and the catalogue's own `isValid(_:)` validator agrees.
//   • Every checklist has a non-empty item list and an escalation
//     note.
//   • No lesson, checklist, source summary, or escalation note
//     uses banned investing-advice / suitability / outcome
//     vocabulary.

import Foundation
import Testing

@testable import NomadFi

struct InvestingEducationCatalogTests {

    // MARK: - Starter scope

    @Test("Supported regions are exactly US + CA in the 8A starter — TT is deferred")
    func supportedRegionsMatchesStarterScope() {
        let regions = Set(InvestingEducationCatalog.supportedRegions)
        #expect(regions == Set([
            InvestingEducationRegion.unitedStates,
            InvestingEducationRegion.canada,
        ]))
    }

    @Test("Every supported region ships at least three starter lessons")
    func minimumLessonCountPerRegion() {
        for region in InvestingEducationCatalog.supportedRegions {
            let lessons = InvestingEducationCatalog.lessons(for: region)
            #expect(
                lessons.count >= 3,
                "\(region.displayName) should ship at least three starter lessons."
            )
        }
    }

    @Test("Every supported region ships exactly one starter checklist with non-empty items")
    func checklistShape() {
        for region in InvestingEducationCatalog.supportedRegions {
            let checklist = InvestingEducationCatalog.checklist(for: region)
            #expect(checklist.region == region)
            #expect(!checklist.title.isEmpty)
            #expect(!checklist.items.isEmpty)
            #expect(!checklist.escalationNote.isEmpty)
        }
    }

    // MARK: - Source backing

    @Test("Every starter lesson carries at least one official-source citation")
    func everyLessonHasOfficialSource() {
        for region in InvestingEducationCatalog.supportedRegions {
            for lesson in InvestingEducationCatalog.lessons(for: region) {
                #expect(
                    !lesson.sources.isEmpty,
                    "Lesson \(lesson.id) must cite at least one official source."
                )
                for source in lesson.sources {
                    #expect(!source.publisher.isEmpty)
                    #expect(!source.title.isEmpty)
                    #expect(!source.url.absoluteString.isEmpty)
                }
            }
        }
    }

    @Test("Every exposed lesson passes the catalogue's own validator")
    func everyLessonIsValid() {
        for region in InvestingEducationCatalog.supportedRegions {
            for lesson in InvestingEducationCatalog.lessons(for: region) {
                #expect(
                    InvestingEducationCatalog.isValid(lesson),
                    "Lesson \(lesson.id) failed catalogue validation."
                )
            }
        }
    }

    @Test("Source publishers are limited to recognised regulators / investor-protection bodies / tax authorities")
    func sourcePublishersAreOfficial() {
        // Hard-coded allow list — adding a new publisher requires
        // an explicit test edit so a brokerage / blog can never
        // sneak into the catalogue silently.
        let allowedPublishers: Set<String> = [
            "Investor.gov / U.S. SEC",
            "IRS",
            "CIRO",
            "CIPF",
            "CRA",
        ]
        for region in InvestingEducationCatalog.supportedRegions {
            for lesson in InvestingEducationCatalog.lessons(for: region) {
                for source in lesson.sources {
                    #expect(
                        allowedPublishers.contains(source.publisher),
                        "Lesson \(lesson.id) cites disallowed publisher: \(source.publisher)"
                    )
                }
            }
        }
    }

    // MARK: - Lesson shape

    @Test("Each lesson has a complete title, what-it-is, why-it-matters, and at least one review prompt")
    func lessonShapeComplete() {
        for region in InvestingEducationCatalog.supportedRegions {
            for lesson in InvestingEducationCatalog.lessons(for: region) {
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
        for region in InvestingEducationCatalog.supportedRegions {
            for lesson in InvestingEducationCatalog.lessons(for: region) {
                #expect(seen.insert(lesson.id).inserted, "Duplicate lesson id: \(lesson.id)")
            }
        }
    }

    @Test("Checklist item ids are globally unique across the catalogue")
    func checklistItemIdsAreGloballyUnique() {
        var seen = Set<String>()
        for region in InvestingEducationCatalog.supportedRegions {
            let checklist = InvestingEducationCatalog.checklist(for: region)
            for item in checklist.items {
                #expect(
                    seen.insert(item.id).inserted,
                    "Duplicate checklist item id: \(item.id)"
                )
            }
        }
    }

    // MARK: - Copy guard

    @Test("No lesson, checklist, source summary, or escalation note uses banned investing-advice phrasing")
    func copyGuardOnCatalogVocabulary() {
        // Banned vocabulary is intentionally tight: outcomes,
        // suitability, recommendation, guarantee, and "best fund"
        // marketing language. Each phrase below would compromise
        // the education-only contract this surface is built on.
        let bannedPhrases: [String] = [
            "best fund",
            "you should buy",
            "you should invest",
            "guaranteed",
            "you'll earn",
            "you will earn",
            "is right for you",
            "this is right",
            "investment advice",
            "personal advice",
            "recommended fund",
            "we recommend",
            "buy this",
            "sell this",
            "outperform",
            "beat the market",
            "high return",
            "low risk",
            "risk-free",
        ]

        var inspected: [String] = []
        for region in InvestingEducationCatalog.supportedRegions {
            let checklist = InvestingEducationCatalog.checklist(for: region)
            inspected.append(checklist.title)
            inspected.append(checklist.escalationNote)
            for item in checklist.items {
                inspected.append(item.text)
            }

            for lesson in InvestingEducationCatalog.lessons(for: region) {
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
