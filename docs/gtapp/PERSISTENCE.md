# GTApp Persistence (SQLite) – APM Guide

This project uses `gtapp_dart`’s SQLite layer (`GTDatabaseService`) for offline-first storage.

## APM dependencies (so the snippets compile)

`gtapp_dart` is re-exported by `gtapp_mobile`, but if APM imports the following packages directly, they must be listed as **direct** dependencies in `audit_pro_mobile/pubspec.yaml`:

```yaml
dependencies:
  # ...existing...
  sqflite: ^2.4.0
  path: ^1.9.0
```

Notes:
- `sqflite` provides `databaseFactory` and `getDatabasesPath()` on Flutter (Android/iOS).
- `path` is used for `p.join(...)`.

## Non‑negotiables (read this first)

1. **All persisted models must extend `DBItem`.**
2. **Every persisted model must be registered** before you call `saveAsync`/`fetch*`.
   - Missing metadata can result in silent no-op saves because `saveAsync` uses `ModelMetadataCache.tryGet(...)`.
3. `toMap()` **must include exactly the scalar columns you registered** (plus `id`).
   - If `scalarProperties` and `toMap()` diverge, raw SQL templates / bulk saves can insert `null`s.
4. Relationships are not stored as nested rows.
   - Lists of child `DBItem`s are stored via **join tables**.
   - Lists of primitives (`List<String>`, `List<int>`, etc.) are stored via **value tables**.

## Lifecycle ordering (bootstrapping)

APM should initialize DB the same way as `gtapp_mobile_template_forms` does:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Configure logging (optional but recommended): `GTLogger.configure(...)`
3. Configure the database singleton: `final db = GTDatabaseService.instance;`
4. Set required fields **before first DB access**:
   - `db.databaseFactory = databaseFactory;` (from `sqflite`)
   - `db.databasePath = ...;` (full path to a `.db` file)
   - optional: `db.filesDirectoryPath = ...;` (enables file cleanup for reset modes)
5. Call `db.configure(DatabaseConfiguration(...))` **before** any DB operations.
  - `configure()` must happen before the first time the DB is opened (i.e. before `await db.database`).
  - If the database is already initialized, `configure()` will fail.
6. Register models (fluent API) – see below.
7. Touch `await db.database;` to force initialization/migrations.

### Platform note: choosing a `databaseFactory`

- Flutter mobile (Android/iOS): set `db.databaseFactory = databaseFactory;` from `sqflite`.
- Dart/CLI or tests: use `sqflite_common_ffi` and set `db.databaseFactory = databaseFactoryFfi;`.

Minimal example (mobile/Flutter):

```dart
import 'package:flutter/material.dart';
import 'package:gtapp_mobile/gtapp_mobile.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GTLogger.configure(
    consoleMinLevel: const bool.fromEnvironment('dart.vm.product')
        ? Level.warning
        : Level.debug,
    isProduction: const bool.fromEnvironment('dart.vm.product'),
  );

  final db = GTDatabaseService.instance;
  db.databaseFactory = databaseFactory;

  final dbDir = await getDatabasesPath();
  db.databasePath = p.join(dbDir, 'audit_pro_mobile.db');

  db.configure(DatabaseConfiguration.production(
    databaseName: 'audit_pro_mobile.db',
    version: 1,
  ));

  await registerModels(db);
  await db.database; // force open + migrate

  runApp(const AuditProApp());
}
```

## Model registration (how tables are created)

Registration does all of this:
- caches metadata (`ModelMetadataCache.register(...)`)
- creates the main table
- creates join tables / value tables
- creates indexes
- applies reset-mode behavior (drop tables, drop changed tables, etc.)

### Fluent API (recommended)

`gtapp_dart` provides `ModelRegistrationBuilder<T>` via an extension on `GTDatabaseService`:

```dart
Future<void> registerModels(GTDatabaseService db) async {
  await db
      .register<MyEntity>()
      .properties(['id', 'name', 'createdAt'])
      .index('name')
      .factory((map) => MyEntity.fromMap(map))
      .build();
}
```

### Relationships (join tables)

```dart
await db
  .register<Parent>()
  .properties(['id', 'title'])
  .hasMany<Child>(
    'children',
    getter: (p) => p.children,
    setter: (p, kids) => p.children = kids,
  )
  .factory((map) => Parent.fromMap(map))
  .build();
```

Notes:
- Default join table name is `{parentTable}_{propertyName}` (e.g. `parents_children`).
- Deletion cascades to orphaned children by default.
- Use `nonRecursive: true` for shared children (many-to-many) to prevent cascade deletion.

### Primitive collections (value tables)

```dart
await db
  .register<Product>()
  .properties(['id', 'name'])
  .hasPrimitiveCollection<String>(
    'tags',
    primitiveType: String,
    getter: (p) => p.tags,
    setter: (p, tags) => p.tags = tags,
  )
  .factory((map) => Product.fromMap(map))
  .build();
```

Notes:
- Default value table name is `{parentTable}_{propertyName}_values`.
- Value tables have columns: `id` (UUID), `parent_id`, `value`.

## CRUD recipes (what actually happens)

### Save

Use `saveAsync(item)` to persist a whole object graph.

Behavior highlights from `GTDatabaseService.saveAsync`:
- calls `item.beforeSave(this)` **before** the transaction
- wraps the entire graph save in **one SQLite transaction**
- calls `item.afterSave(this)` after commit (exceptions here don’t rollback)

```dart
final result = await db.saveAsync(order);
if (!result.success) throw Exception(result.message);
```

### Fetch and hydration depth

`fetchByIdAsync(id, depth: n)`:
- `depth == 0` loads the entity + **primitive collections**
- `depth > 0` loads entity children recursively up to `n` levels

```dart
final order = (await db.fetchByIdAsync<Order>(id, depth: 2)).data;
```

If you fetched with `depth: 0` and later need relationships:

```dart
await db.hydrateAsync(order, 2);
```

### Bulk save

`saveAllAsync(items)` is much faster than saving one-by-one (it batches by level).

### Delete (cascade + orphan detection)

`deleteAsync(item)`:
- removes join table links
- deletes primitive value table entries
- finds orphaned children (no remaining join-table references) and deletes them recursively
- honors `nonRecursiveDelete` on relationships

```dart
await db.deleteAsync(order);
```

## Reset modes and migrations (don’t guess)

Use `DatabaseConfiguration` + `DatabaseResetMode`:
- `none`: production default (preserve data)
- `resetDataOnly`: wipe tables (testing)
- `resetTablesIfChanged`: drop only changed tables (active dev)
- `resetDatabaseCompletely`: delete the whole DB file (integration tests)

Schema upgrades:
- On version bump, `_onUpgrade` either drops everything (if reset mode says so) or applies configured migrations.
- In production, if you bump `version` you should also provide `migrations` in `DatabaseConfiguration`.

## File deletion integration

`GTDatabaseService` supports deleting physical files when deleting an entity:
- Set `ModelMetadata.filePathPropertyName` (e.g. `'localPath'`)
- When `deleteAsync` runs, it deletes the physical file **before** deleting DB metadata.

Important: saving/creating physical files is currently **not** automatic; `_processPhysicalFileIfPending` is a placeholder. If your entity represents a file, create the file yourself (typically in `beforeSave`).
