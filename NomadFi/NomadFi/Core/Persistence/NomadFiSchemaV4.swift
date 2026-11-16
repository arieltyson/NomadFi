import SwiftData

/// Adds the person's merchant spending rules. Only a new model type, so
/// existing stores move forward with a lightweight migration.
enum NomadFiSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        NomadFiSchemaV3.models + [MerchantSpendingRule.self]
    }
}
