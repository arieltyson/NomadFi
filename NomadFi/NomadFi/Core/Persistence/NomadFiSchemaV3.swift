import SwiftData

enum NomadFiSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        NomadFiSchemaV2.models + [FiBotWorkspace.self, FiBotDecisionRecord.self]
    }
}
