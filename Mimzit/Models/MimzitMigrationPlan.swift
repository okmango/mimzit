import SwiftData

/// SwiftData schema migration plan for Mimzit.
///
/// ## Adding New Versions
/// 1. Create a new `MimzitSchemaVN` enum conforming to `VersionedSchema`
/// 2. Add it to `schemas` array
/// 3. Add a `MigrationStage` to `stages` if needed
///
/// ## Current Version
/// V1.0.0 — Initial schema with ReferenceContent model.
enum MimzitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] { [MimzitSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// Schema V1.0.0 — initial Mimzit data model.
enum MimzitSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ReferenceContent.self] }
}
