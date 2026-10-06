import SwiftData

enum NomadFiSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { NomadFiSchemaV1.models + [HostedLocalState.self] }
}
