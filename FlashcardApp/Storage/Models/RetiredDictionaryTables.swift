import RealmSwift

/// Stand-ins for the tables of the retired bundled dictionary (`RJaVi`, `RViJa`, `RKanji`, `RGrammar`, `RExample`).
/// They are not part of the schema: they only give the schema-2 migration a class to name when it empties those
/// tables in an upgraded install, because Realm cannot delete the data of a type no class describes.
final class RetiredJaVi: Object {
    @Persisted var id: Int
    override class func _realmObjectName() -> String? { "RJaVi" }
}
final class RetiredViJa: Object {
    @Persisted var id: Int
    override class func _realmObjectName() -> String? { "RViJa" }
}
final class RetiredKanji: Object {
    @Persisted var id: Int
    override class func _realmObjectName() -> String? { "RKanji" }
}
final class RetiredGrammar: Object {
    @Persisted var id: Int
    override class func _realmObjectName() -> String? { "RGrammar" }
}
final class RetiredExample: Object {
    @Persisted var id: Int
    override class func _realmObjectName() -> String? { "RExample" }
}
