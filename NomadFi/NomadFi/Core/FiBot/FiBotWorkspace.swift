import Foundation
import SwiftData

@Model
final class FiBotWorkspace {
    var id: UUID = UUID()
    var revision: UUID = UUID()
    var planData: Data = Data()
    var updatedAt: Date = Date.now
    init(planData: Data) { self.planData = planData }
}

@Model
final class FiBotDecisionRecord {
    var id: UUID = UUID()
    var planRevision: UUID = UUID()
    var createdAt: Date = Date.now
    var question: String = ""
    var contextData: Data = Data()
    var purchaseData: Data = Data()
    var decisionData: Data = Data()
    var evidenceVersion: String = ""
    init(planRevision: UUID, question: String, contextData: Data, purchaseData: Data, decisionData: Data) {
        self.planRevision = planRevision; self.question = question; self.contextData = contextData
        self.purchaseData = purchaseData; self.decisionData = decisionData
        evidenceVersion = FiBotEvidenceRegistry.version
    }
}

@MainActor
enum FiBotWorkspaceStore {
    enum Failure: Error { case invalidPlan, staleDecision, cannotReserve }

    static func load(in context: ModelContext) throws -> (FiBotPlan, UUID?) {
        guard let row = try context.fetch(FetchDescriptor<FiBotWorkspace>()).first else { return (.init(), nil) }
        return (try JSONDecoder().decode(FiBotPlan.self, from: row.planData), row.revision)
    }

    @discardableResult
    static func save(_ plan: FiBotPlan, in context: ModelContext) throws -> UUID {
        _ = try load(in: context)
        guard plan.accounts.count <= 100, plan.schedules.count <= 250, plan.commitments.count <= 1000 else { throw Failure.invalidPlan }
        let data = try JSONEncoder().encode(plan)
        guard data.count <= 1_048_576 else { throw Failure.invalidPlan }
        let row = try context.fetch(FetchDescriptor<FiBotWorkspace>()).first ?? FiBotWorkspace(planData: data)
        if row.modelContext == nil { context.insert(row) }
        row.planData = data; row.revision = UUID(); row.updatedAt = .now
        try context.save()
        return row.revision
    }

    static func evaluate(question: String, purchase: FiBotPurchase, in context: ModelContext, now: Date = .now) throws -> FiBotDecisionRecord {
        let (plan, revision) = try load(in: context)
        guard let revision else { throw Failure.invalidPlan }
        let snapshot = FiBotContextBuilder.build(plan: plan, on: FiBotCalendar.string(now))
        let decision = FiBotAffordabilityEngine.evaluate(context: snapshot, purchase: purchase, policy: plan.policy)
        let encoder = JSONEncoder()
        let row = FiBotDecisionRecord(planRevision: revision, question: String(question.prefix(500)),
            contextData: try encoder.encode(snapshot), purchaseData: try encoder.encode(purchase), decisionData: try encoder.encode(decision))
        row.createdAt = now
        context.insert(row)
        let records = try context.fetch(FetchDescriptor<FiBotDecisionRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        for (index, record) in records.enumerated() where index >= 50 || now.timeIntervalSince(record.createdAt) > 30 * 86400 {
            context.delete(record)
        }
        try context.save()
        return row
    }

    static func reserve(_ record: FiBotDecisionRecord, in context: ModelContext, now: Date = .now) throws {
        var (plan, revision) = try load(in: context)
        guard revision == record.planRevision, now.timeIntervalSince(record.createdAt) >= 0,
              now.timeIntervalSince(record.createdAt) <= 3600 else { throw Failure.staleDecision }
        let purchase = try JSONDecoder().decode(FiBotPurchase.self, from: record.purchaseData)
        let snapshot = FiBotContextBuilder.build(plan: plan, on: FiBotCalendar.string(now))
        guard FiBotAffordabilityEngine.evaluate(context: snapshot, purchase: purchase, policy: plan.policy).outcome == .affordable,
              purchase.ownershipCosts.isEmpty,
              !plan.commitments.contains(where: { $0.id == record.id.uuidString }) else { throw Failure.cannotReserve }
        plan.commitments.append(.init(id: record.id.uuidString, accountID: purchase.fundingAccountID,
            money: purchase.allInCost, expiresOn: FiBotCalendar.string(now.addingTimeInterval(7 * 86400))))
        try save(plan, in: context)
    }

    static func erase(in context: ModelContext) throws {
        try context.delete(model: FiBotDecisionRecord.self)
        try context.delete(model: FiBotWorkspace.self)
        try context.save()
    }
}
