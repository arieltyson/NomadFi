import SwiftData

enum NomadFiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NomadFiSchemaV1.self, NomadFiSchemaV2.self, NomadFiSchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: NomadFiSchemaV1.self, toVersion: NomadFiSchemaV2.self),
         .lightweight(fromVersion: NomadFiSchemaV2.self, toVersion: NomadFiSchemaV3.self)]
    }
}
