import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:audit_pro_mobile/apm/models/collection_config.dart';
import 'package:audit_pro_mobile/apm/models/heat_meter.dart';
import 'package:audit_pro_mobile/apm/models/plate_heat_exchanger.dart';
import 'package:audit_pro_mobile/apm/models/heat_generator.dart';
import 'package:audit_pro_mobile/apm/models/communal_control.dart';
import 'package:audit_pro_mobile/apm/models/dhw_plant.dart';
import 'package:audit_pro_mobile/apm/models/dwelling_inspection.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  static const String _currentFormKeyPrefix = 'current_form_id.';

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    // Fresh schema snapshot (dev-only, pre-production). Bumping the DB filename
    // avoids carrying forward legacy upgrade debt while the data model is still
    // evolving.
    final path = join(dbPath, 'apm_forms_v14.db');

    return await openDatabase(
      path,
      version: 32,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Forms table - stores the main form data
    await db.execute('''
      CREATE TABLE forms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        form_type TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        form_data TEXT NOT NULL
      )
    ''');

    // Observations table - stores observations with their notes
    await db.execute('''
      CREATE TABLE observations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        attached_to_type TEXT NOT NULL,
        attached_to_id TEXT NOT NULL,
        attached_to_path TEXT,
        question_reference TEXT,
        notes TEXT,
        question_text TEXT,
        section_name TEXT,
        asset_id INTEGER,
        asset_type TEXT,
        asset_make_model TEXT,
        is_unsafe INTEGER DEFAULT 0,
        unsafe_classification TEXT,
        unsafe_action_taken TEXT,
        unsafe_warning_notice_image TEXT,
        unsafe_after_image TEXT,
        unsafe_resident_reaction TEXT,
        unsafe_reported_to_client TEXT,
        unsafe_reported_internally TEXT,
        unsafe_checked_by TEXT,
        unsafe_checked_date TEXT,
        unsafe_sent_via TEXT,
        unsafe_sent_to TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    // Observation images table - stores image paths linked to observations
    await db.execute('''
      CREATE TABLE observation_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        observation_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (observation_id) REFERENCES observations (id) ON DELETE CASCADE
      )
    ''');

    // Settings table - stores app settings as key-value pairs
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Clients table - stores managed client list
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Property Types table - stores managed property type list
    await db.execute('''
      CREATE TABLE property_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Asset Statuses table - stores managed asset status list
    await db.execute('''
      CREATE TABLE asset_statuses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Input Suggestions table - stores autocomplete suggestions with context
    await db.execute('''
      CREATE TABLE input_suggestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_name TEXT NOT NULL,
        value TEXT NOT NULL,
        filter_context TEXT,
        usage_count INTEGER DEFAULT 1,
        last_used TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create index for fast suggestion lookups
    await db.execute('''
      CREATE INDEX idx_suggestions_lookup 
      ON input_suggestions(field_name, filter_context, value)
    ''');

    // Asset Types table - stores maintained asset type configurations
    await db.execute('''
      CREATE TABLE asset_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_type TEXT NOT NULL,
        domestic_commercial TEXT NOT NULL,
        expected_service_life INTEGER,
        base_value TEXT,
        value_modifier REAL,
        image_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Assets table - stores individual assets for each report
    await db.execute('''
      CREATE TABLE assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        asset_type_id INTEGER NOT NULL,
        asset_make TEXT,
        asset_model TEXT,
        location TEXT,
        estimate_age INTEGER,
        operational TEXT,
        status TEXT,
        visual_condition TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE,
        FOREIGN KEY (asset_type_id) REFERENCES asset_types (id)
      )
    ''');

    // Asset images table - stores image paths linked to assets
    await db.execute('''
      CREATE TABLE asset_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (asset_id) REFERENCES assets (id) ON DELETE CASCADE
      )
    ''');

    // Asset observations table - stores observations linked to assets
    await db.execute('''
      CREATE TABLE asset_observations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (asset_id) REFERENCES assets (id) ON DELETE CASCADE
      )
    ''');

    // Asset observation images table - stores image paths linked to asset observations
    await db.execute('''
      CREATE TABLE asset_observation_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_observation_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (asset_observation_id) REFERENCES asset_observations (id) ON DELETE CASCADE
      )
    ''');

    // Create indices for faster queries
    await db.execute(
      'CREATE INDEX idx_forms_status ON forms (status, form_type)',
    );
    await db.execute(
      'CREATE INDEX idx_observations_form ON observations (form_id)',
    );
    await db.execute(
      'CREATE INDEX idx_observations_attached_to ON observations (form_id, attached_to_type, attached_to_id)',
    );
    await db.execute(
      'CREATE INDEX idx_observation_images ON observation_images (observation_id)',
    );
    await db.execute('CREATE INDEX idx_assets_form ON assets (form_id)');
    await db.execute(
      'CREATE INDEX idx_asset_images ON asset_images (asset_id)',
    );
    await db.execute(
      'CREATE INDEX idx_asset_observations ON asset_observations (asset_id)',
    );
    await db.execute(
      'CREATE INDEX idx_asset_observation_images ON asset_observation_images (asset_observation_id)',
    );

    // Unsafe Reports table - stores formal unsafe situation reports
    await db.execute('''
      CREATE TABLE unsafe_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        action_taken TEXT,
        warning_notice_image TEXT,
        after_image TEXT,
        reported_to_client TEXT,
        reported_internally TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    // Report Observations junction table - links reports to observations
    await db.execute('''
      CREATE TABLE report_observations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        observation_id INTEGER NOT NULL,
        FOREIGN KEY (report_id) REFERENCES unsafe_reports (id) ON DELETE CASCADE,
        FOREIGN KEY (observation_id) REFERENCES observations (id) ON DELETE CASCADE,
        UNIQUE(report_id, observation_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_unsafe_reports_form ON unsafe_reports (form_id)',
    );
    await db.execute(
      'CREATE INDEX idx_report_observations_report ON report_observations (report_id)',
    );
    await db.execute(
      'CREATE INDEX idx_report_observations_observation ON report_observations (observation_id)',
    );

    // Pre-seed asset types
    final now = DateTime.now().toIso8601String();
    final assetTypes = [
      {
        'asset_type': 'Boiler',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 15,
        'base_value': '10000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Water Heater',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 15,
        'base_value': '10000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Gas Meter',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 25,
        'base_value': '5000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Calorifier',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 20,
        'base_value': '10000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Buffer Vessel',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 20,
        'base_value': '10000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Gas Solenoid',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 20,
        'base_value': '5000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Pressurisation Unit',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 15,
        'base_value': '5000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Expansion Vessel',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 15,
        'base_value': '5000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Magnetic Filter',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 15,
        'base_value': '5000',
        'value_modifier': 1.0,
      },
      {
        'asset_type': 'Dosing Pot',
        'domestic_commercial': 'Commercial',
        'expected_service_life': 15,
        'base_value': '5000',
        'value_modifier': 1.0,
      },
    ];

    for (final assetType in assetTypes) {
      await db.insert('asset_types', {
        ...assetType,
        'created_at': now,
        'updated_at': now,
      });
    }

    // Pre-seed all collections from configuration
    for (final collection in AppCollections.all) {
      for (final item in collection.seedData) {
        await db.insert(collection.tableName, {
          'name': item,
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    // Plant Rooms table - stores multiple plant rooms per site
    await db.execute('''
      CREATE TABLE plant_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        location TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    // Plant Room Images table - stores access and internal images
    await db.execute('''
      CREATE TABLE plant_room_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_room_id INTEGER NOT NULL,
        image_type TEXT NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (plant_room_id) REFERENCES plant_rooms (id) ON DELETE CASCADE
      )
    ''');

    // Plant Room Responses table - stores subsection question responses
    await db.execute('''
      CREATE TABLE plant_room_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_room_id INTEGER NOT NULL,
        question_key TEXT NOT NULL,
        answer_value TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plant_room_id) REFERENCES plant_rooms (id) ON DELETE CASCADE,
        UNIQUE(plant_room_id, question_key)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_plant_rooms_form ON plant_rooms (form_id)',
    );
    await db.execute(
      'CREATE INDEX idx_plant_room_images ON plant_room_images (plant_room_id)',
    );
    await db.execute(
      'CREATE INDEX idx_plant_room_responses ON plant_room_responses (plant_room_id)',
    );

    // Heat Meters table
    await db.execute('''
      CREATE TABLE heat_meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        meter_type TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        location TEXT NOT NULL,
        age_range TEXT NOT NULL,
        serial_number TEXT,
        operational TEXT NOT NULL,
        reading TEXT,
        related_asset_type TEXT,
        related_asset_id INTEGER,
        image_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_heat_meters_form ON heat_meters (form_id)',
    );

    // Plate Heat Exchangers table
    await db.execute('''
      CREATE TABLE plate_heat_exchangers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        location TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        serial_number TEXT,
        capacity TEXT,
        age_range TEXT NOT NULL,
        condition TEXT NOT NULL,
        insulation_condition TEXT,
        free_of_leaks TEXT,
        has_isolation_valves TEXT,
        has_temp_gauges TEXT,
        has_individual_meter TEXT,
        image_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_plate_heat_exchangers_form ON plate_heat_exchangers (form_id)',
    );

    // Heat Generators table
    await db.execute('''
      CREATE TABLE heat_generators (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        generator_type TEXT NOT NULL,
        fuel_type TEXT NOT NULL,
        location TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        serial_number TEXT,
        capacity TEXT,
        age_range TEXT NOT NULL,
        condition TEXT NOT NULL,
        operational TEXT,
        has_individual_meter TEXT,
        image_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_heat_generators_form ON heat_generators (form_id)',
    );

    // DHW Plant table
    await db.execute('''
      CREATE TABLE dhw_plants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        plant_type TEXT NOT NULL,
        fuel_type TEXT,
        location TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        serial_number TEXT,
        capacity TEXT,
        heat_input TEXT,
        age_range TEXT NOT NULL,
        condition TEXT NOT NULL,
        operational TEXT,
        image_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_dhw_plants_form ON dhw_plants (form_id)',
    );

    // Communal Controls table
    await db.execute('''
      CREATE TABLE communal_controls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        control_type TEXT NOT NULL,
        location TEXT,
        make TEXT,
        model TEXT,
        serial_number TEXT,
        condition TEXT,
        operational TEXT,
        image_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_communal_controls_form ON communal_controls (form_id)',
    );

    // Dwelling Inspections table
    await db.execute('''
      CREATE TABLE dwelling_inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id INTEGER NOT NULL,
        location TEXT NOT NULL,
        heating_type TEXT,
        heat_generator_type TEXT,
        heat_generator_fuel_type TEXT,
        heat_distribution_type TEXT,
        dhw_type TEXT,
        dhw_generator_type TEXT,
        dhw_generator_fuel_type TEXT,
        dhw_communal_type TEXT,
        heating_controls TEXT,
        heating_controls_other TEXT,
        heating_notes TEXT,
        heating_image_paths TEXT,
        dhw_controls TEXT,
        dhw_controls_other TEXT,
        dhw_notes TEXT,
        dhw_image_paths TEXT,
        heating_metered TEXT,
        dhw_metered TEXT,
        heating_sub_meter_feasible TEXT,
        heating_sub_meter_feasibility_reason TEXT,
        heating_sub_meter_evidence_images TEXT,
        dhw_sub_meter_feasible TEXT,
        dhw_sub_meter_feasibility_reason TEXT,
        dhw_sub_meter_evidence_images TEXT,
        hiu_make TEXT,
        hiu_model TEXT,
        hiu_serial_number TEXT,
        condition TEXT,
        operational TEXT,
        image_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_dwelling_inspections_form ON dwelling_inspections (form_id)',
    );

    // Pre-seed location suggestions
    final locationSuggestions = [
      'Plant Room',
      'Meter Room',
      'Kitchen',
      'Office',
    ];

    for (final location in locationSuggestions) {
      await db.insert('input_suggestions', {
        'field_name': 'location',
        'value': location,
        'filter_context': null,
        'usage_count': 1,
        'last_used': now,
        'created_at': now,
      });
    }

    // APK downloads - tracks downloaded update packages for cleanup after install.
    await db.execute('''
      CREATE TABLE apk_downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        download_url TEXT NOT NULL,
        local_path TEXT NOT NULL,
        version_name TEXT,
        version_code INTEGER,
        created_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_apk_downloads_active ON apk_downloads (is_deleted, created_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add settings table for version 2
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add asset-related tables for version 3
      await db.execute('''
        CREATE TABLE asset_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_type TEXT NOT NULL,
          domestic_commercial TEXT NOT NULL,
          expected_service_life INTEGER,
          base_value TEXT,
          value_modifier REAL,
          image_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE assets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          asset_type_id INTEGER NOT NULL,
          asset_make TEXT,
          asset_model TEXT,
          location TEXT,
          estimate_age INTEGER,
          operational TEXT,
          status TEXT,
          visual_condition TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE,
          FOREIGN KEY (asset_type_id) REFERENCES asset_types (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE asset_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_id INTEGER NOT NULL,
          image_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (asset_id) REFERENCES assets (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE asset_observations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_id INTEGER NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (asset_id) REFERENCES assets (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE asset_observation_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_observation_id INTEGER NOT NULL,
          image_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (asset_observation_id) REFERENCES asset_observations (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX idx_assets_form ON assets (form_id)');
      await db.execute(
        'CREATE INDEX idx_asset_images ON asset_images (asset_id)',
      );
      await db.execute(
        'CREATE INDEX idx_asset_observations ON asset_observations (asset_id)',
      );
      await db.execute(
        'CREATE INDEX idx_asset_observation_images ON asset_observation_images (asset_observation_id)',
      );
    }
    if (oldVersion < 4) {
      // Add unsafe situation fields to observations table
      await db.execute('''
        ALTER TABLE observations ADD COLUMN is_unsafe INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_action_taken TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_warning_notice_image TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_after_image TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_resident_reaction TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_reported_to_client TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_reported_internally TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_checked_by TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_checked_date TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_sent_via TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_sent_to TEXT
      ''');
    }
    if (oldVersion < 5) {
      // Add context fields to observations table
      await db.execute('''
        ALTER TABLE observations ADD COLUMN question_text TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN section_name TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN asset_id INTEGER
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN asset_type TEXT
      ''');
      await db.execute('''
        ALTER TABLE observations ADD COLUMN asset_make_model TEXT
      ''');
    }
    if (oldVersion < 6) {
      // Add unsafe reports tables for version 6
      await db.execute('''\n        CREATE TABLE unsafe_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          report_title TEXT,
          action_taken TEXT,
          warning_notice_image TEXT,
          after_image TEXT,
          resident_reaction TEXT,
          reported_to_client TEXT,
          reported_internally TEXT,
          checked_by TEXT,
          checked_date TEXT,
          sent_via TEXT,
          sent_to TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''\n        CREATE TABLE report_observations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          observation_id INTEGER NOT NULL,
          FOREIGN KEY (report_id) REFERENCES unsafe_reports (id) ON DELETE CASCADE,
          FOREIGN KEY (observation_id) REFERENCES observations (id) ON DELETE CASCADE,
          UNIQUE(report_id, observation_id)
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_unsafe_reports_form ON unsafe_reports (form_id)',
      );
      await db.execute(
        'CREATE INDEX idx_report_observations_report ON report_observations (report_id)',
      );
      await db.execute(
        'CREATE INDEX idx_report_observations_observation ON report_observations (observation_id)',
      );
    }
    if (oldVersion < 7) {
      // Add unsafe_classification to observations table
      await db.execute('''
        ALTER TABLE observations ADD COLUMN unsafe_classification TEXT
      ''');
    }
    if (oldVersion < 8) {
      // Add clients and property_types tables
      await db.execute('''
        CREATE TABLE clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE property_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Pre-seed all collections for migration
      final now = DateTime.now().toIso8601String();
      for (final collection in AppCollections.all) {
        for (final item in collection.seedData) {
          await db.insert(collection.tableName, {
            'name': item,
            'created_at': now,
            'updated_at': now,
          });
        }
      }
    }
    if (oldVersion < 9) {
      // Add input_suggestions table for autocomplete
      await db.execute('''
        CREATE TABLE input_suggestions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          field_name TEXT NOT NULL,
          value TEXT NOT NULL,
          filter_context TEXT,
          usage_count INTEGER DEFAULT 1,
          last_used TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_suggestions_lookup 
        ON input_suggestions(field_name, filter_context, value)
      ''');

      // Pre-seed location suggestions
      final now = DateTime.now().toIso8601String();
      final locationSuggestions = [
        'Plant Room',
        'Meter Room',
        'Kitchen',
        'Office',
      ];

      for (final location in locationSuggestions) {
        await db.insert('input_suggestions', {
          'field_name': 'location',
          'value': location,
          'filter_context': null,
          'usage_count': 1,
          'last_used': now,
          'created_at': now,
        });
      }
    }
    if (oldVersion < 10) {
      // Add asset_statuses table
      await db.execute('''
        CREATE TABLE asset_statuses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Pre-seed asset statuses
      final now = DateTime.now().toIso8601String();
      final statuses = [
        'Operational',
        'Isolated',
        'Corrosion Evident',
        'Leaking',
        'Faul State',
        'Unsafe',
      ];

      for (final status in statuses) {
        await db.insert('asset_statuses', {
          'name': status,
          'created_at': now,
          'updated_at': now,
        });
      }
    }
    if (oldVersion < 11) {
      // Add plant_rooms table for multiple plant rooms per site
      await db.execute('''
        CREATE TABLE plant_rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          location TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');

      // Add plant_room_images table for access and internal images
      await db.execute('''
        CREATE TABLE plant_room_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plant_room_id INTEGER NOT NULL,
          image_type TEXT NOT NULL,
          image_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (plant_room_id) REFERENCES plant_rooms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_plant_rooms_form ON plant_rooms (form_id)',
      );
      await db.execute(
        'CREATE INDEX idx_plant_room_images ON plant_room_images (plant_room_id)',
      );
    }
    if (oldVersion < 12) {
      // Add plant_room_responses table for subsection question responses
      await db.execute('''
        CREATE TABLE plant_room_responses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plant_room_id INTEGER NOT NULL,
          question_key TEXT NOT NULL,
          answer_value TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (plant_room_id) REFERENCES plant_rooms (id) ON DELETE CASCADE,
          UNIQUE(plant_room_id, question_key)
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_plant_room_responses ON plant_room_responses (plant_room_id)',
      );

      // Add plant_room_id to observations table for plant room context
      await db.execute('''
        ALTER TABLE observations ADD COLUMN plant_room_id INTEGER
      ''');

      await db.execute(
        'CREATE INDEX idx_observations_plant_room ON observations (plant_room_id)',
      );
    }
    if (oldVersion < 13) {
      // Add heat_meters table
      await db.execute('''
        CREATE TABLE heat_meters (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          meter_type TEXT NOT NULL,
          make TEXT NOT NULL,
          model TEXT NOT NULL,
          location TEXT NOT NULL,
          age_range TEXT NOT NULL,
          serial_number TEXT,
          operational TEXT NOT NULL,
          reading TEXT,
          image_paths TEXT,
          related_asset_type TEXT,
          related_asset_id INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_heat_meters_form ON heat_meters (form_id)',
      );
    }

    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE plate_heat_exchangers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          location TEXT NOT NULL,
          make TEXT NOT NULL,
          model TEXT NOT NULL,
          serial_number TEXT,
          capacity TEXT,
          age_range TEXT NOT NULL,
          condition TEXT NOT NULL,
          insulation_condition TEXT,
          free_of_leaks TEXT,
          has_isolation_valves TEXT,
          has_temp_gauges TEXT,
          has_individual_meter TEXT,
          image_paths TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_plate_heat_exchangers_form ON plate_heat_exchangers (form_id)',
      );
    }

    if (oldVersion < 16) {
      // Check for missing columns in plate_heat_exchangers and add them if needed
      // This handles cases where the table was created with an older schema

      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(plate_heat_exchangers)',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      final missingColumns = [
        'capacity',
        'free_of_leaks',
        'has_isolation_valves',
        'has_temp_gauges',
        'has_individual_meter',
        'insulation_condition',
      ];

      for (final col in missingColumns) {
        if (!columnNames.contains(col)) {
          await db.execute(
            'ALTER TABLE plate_heat_exchangers ADD COLUMN $col TEXT',
          );
        }
      }
    }
    if (oldVersion < 17) {
      // Add related asset columns to heat_meters
      // Check first to avoid errors
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(heat_meters)',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('related_asset_type')) {
        await db.execute(
          'ALTER TABLE heat_meters ADD COLUMN related_asset_type TEXT',
        );
      }
      if (!columnNames.contains('related_asset_id')) {
        await db.execute(
          'ALTER TABLE heat_meters ADD COLUMN related_asset_id INTEGER',
        );
      }
    }

    if (oldVersion < 27) {
      // Ensure related asset columns exist for heat_meters (new installs before v27)
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(heat_meters)',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('related_asset_type')) {
        await db.execute(
          'ALTER TABLE heat_meters ADD COLUMN related_asset_type TEXT',
        );
      }
      if (!columnNames.contains('related_asset_id')) {
        await db.execute(
          'ALTER TABLE heat_meters ADD COLUMN related_asset_id INTEGER',
        );
      }
    }

    if (oldVersion < 28) {
      // Ensure sub-meter feasibility columns exist for dwelling_inspections
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(dwelling_inspections)',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('heating_sub_meter_feasible')) {
        await db.execute(
          'ALTER TABLE dwelling_inspections ADD COLUMN heating_sub_meter_feasible TEXT',
        );
      }
      if (!columnNames.contains('heating_sub_meter_feasibility_reason')) {
        await db.execute(
          'ALTER TABLE dwelling_inspections ADD COLUMN heating_sub_meter_feasibility_reason TEXT',
        );
      }
      if (!columnNames.contains('heating_sub_meter_evidence_images')) {
        await db.execute(
          'ALTER TABLE dwelling_inspections ADD COLUMN heating_sub_meter_evidence_images TEXT',
        );
      }
      if (!columnNames.contains('dhw_sub_meter_feasible')) {
        await db.execute(
          'ALTER TABLE dwelling_inspections ADD COLUMN dhw_sub_meter_feasible TEXT',
        );
      }
      if (!columnNames.contains('dhw_sub_meter_feasibility_reason')) {
        await db.execute(
          'ALTER TABLE dwelling_inspections ADD COLUMN dhw_sub_meter_feasibility_reason TEXT',
        );
      }
      if (!columnNames.contains('dhw_sub_meter_evidence_images')) {
        await db.execute(
          'ALTER TABLE dwelling_inspections ADD COLUMN dhw_sub_meter_evidence_images TEXT',
        );
      }
    }

    if (oldVersion < 31) {
      // Tenant controls + per-section notes/photos for dwelling_inspections
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(dwelling_inspections)',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      Future<void> ensureColumn(String name, String type) async {
        if (!columnNames.contains(name)) {
          await db.execute(
            'ALTER TABLE dwelling_inspections ADD COLUMN $name $type',
          );
        }
      }

      await ensureColumn('heating_controls', 'TEXT');
      await ensureColumn('heating_controls_other', 'TEXT');
      await ensureColumn('heating_notes', 'TEXT');
      await ensureColumn('heating_image_paths', 'TEXT');
      await ensureColumn('dhw_controls', 'TEXT');
      await ensureColumn('dhw_controls_other', 'TEXT');
      await ensureColumn('dhw_notes', 'TEXT');
      await ensureColumn('dhw_image_paths', 'TEXT');
    }

    if (oldVersion < 18) {
      await db.execute('''
        CREATE TABLE heat_generators (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          generator_type TEXT NOT NULL,
          fuel_type TEXT NOT NULL,
          location TEXT NOT NULL,
          make TEXT NOT NULL,
          model TEXT NOT NULL,
          serial_number TEXT,
          capacity TEXT,
          age_range TEXT NOT NULL,
          condition TEXT NOT NULL,
          operational TEXT,
          has_individual_meter TEXT,
          image_paths TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_heat_generators_form ON heat_generators (form_id)',
      );
    }

    // Version 19 - Update heat_generators table schema
    if (oldVersion < 19) {
      // Check if operational column exists, if not add it
      var columns = await db.rawQuery('PRAGMA table_info(heat_generators)');
      var columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('operational')) {
        await db.execute(
          'ALTER TABLE heat_generators ADD COLUMN operational TEXT',
        );
      }
    }

    // Version 20 - Add communal_controls table
    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE communal_controls (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          control_type TEXT NOT NULL,
          location TEXT,
          make TEXT,
          model TEXT,
          serial_number TEXT,
          condition TEXT,
          operational TEXT,
          image_paths TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_communal_controls_form ON communal_controls (form_id)',
      );
    }

    // Version 21 - Add dwelling_inspections table
    if (oldVersion < 21) {
      await db.execute('''
        CREATE TABLE dwelling_inspections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          location TEXT NOT NULL,
          floor TEXT,
          hiu_make TEXT,
          hiu_model TEXT,
          hiu_serial_number TEXT,
          condition TEXT,
          operational TEXT,
          image_paths TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_dwelling_inspections_form ON dwelling_inspections (form_id)',
      );
    }

    // Version 22 - Add new columns to dwelling_inspections
    if (oldVersion < 22) {
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heating_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heat_generator_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heat_generator_fuel_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heat_distribution_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_generator_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_generator_fuel_type TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_communal_type TEXT',
      );
    }

    // Version 23 - Add metering columns to dwelling_inspections
    if (oldVersion < 23) {
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heating_metered TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_metered TEXT',
      );
    }

    // Version 24 - Add sub-meter feasibility columns
    if (oldVersion < 24) {
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heating_sub_meter_feasible TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heating_sub_meter_feasibility_reason TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN heating_sub_meter_evidence_images TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_sub_meter_feasible TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_sub_meter_feasibility_reason TEXT',
      );
      await db.execute(
        'ALTER TABLE dwelling_inspections ADD COLUMN dhw_sub_meter_evidence_images TEXT',
      );
    }

    // Version 25 - Add DHW plant table
    if (oldVersion < 25) {
      await db.execute('''
        CREATE TABLE dhw_plants (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          form_id INTEGER NOT NULL,
          plant_type TEXT NOT NULL,
          location TEXT NOT NULL,
          make TEXT NOT NULL,
          model TEXT NOT NULL,
          serial_number TEXT,
          capacity TEXT,
          age_range TEXT NOT NULL,
          condition TEXT NOT NULL,
          operational TEXT,
          image_paths TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (form_id) REFERENCES forms (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_dhw_plants_form ON dhw_plants (form_id)',
      );
    }

    // Version 26 - Add heat_input to dhw_plants
    if (oldVersion < 26) {
      await db.execute('ALTER TABLE dhw_plants ADD COLUMN heat_input TEXT');
    }

    // Version 29 - Add fuel_type to dhw_plants
    if (oldVersion < 29) {
      await db.execute('ALTER TABLE dhw_plants ADD COLUMN fuel_type TEXT');
    }

    if (oldVersion < 30) {
      await db.execute('''
        CREATE TABLE apk_downloads (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          download_url TEXT NOT NULL,
          local_path TEXT NOT NULL,
          version_name TEXT,
          version_code INTEGER,
          created_at TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at TEXT
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_apk_downloads_active ON apk_downloads (is_deleted, created_at)',
      );
    }

    if (oldVersion < 32) {
      // Add stable UUID identity for forms (cross-device safe, unlike autoincrement id).
      await db.execute("ALTER TABLE forms ADD COLUMN uuid TEXT");

      final existing = await db.query('forms', columns: ['id', 'uuid']);
      for (final row in existing) {
        final id = row['id'] as int?;
        final uuid = row['uuid']?.toString();
        if (id == null) continue;
        if (uuid != null && uuid.trim().isNotEmpty) continue;

        await db.update(
          'forms',
          {'uuid': _newUuidV4()},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  static String _newUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Set version to 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).toList(growable: false);

    return '${b[0]}${b[1]}${b[2]}${b[3]}-'
        '${b[4]}${b[5]}-'
        '${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-'
        '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  // ========== APK DOWNLOAD TRACKING ==========

  Future<int> insertApkDownload({
    required String downloadUrl,
    required String localPath,
    String? versionName,
    int? versionCode,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();

    return db.insert('apk_downloads', {
      'download_url': downloadUrl,
      'local_path': localPath,
      'version_name': versionName,
      'version_code': versionCode,
      'created_at': now,
      'is_deleted': 0,
      'deleted_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> getActiveApkDownloads() async {
    final db = await database;
    final rows = await db.query(
      'apk_downloads',
      where: 'is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> markApkDownloadDeleted(int id) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'apk_downloads',
      {'is_deleted': 1, 'deleted_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== DHW PLANT OPERATIONS ==========

  Future<int> saveDhwPlant(DhwPlant plant) async {
    final db = await database;
    final map = plant.toMap();

    if (plant.id == null) {
      return await db.insert('dhw_plants', map);
    } else {
      await db.update(
        'dhw_plants',
        map,
        where: 'id = ?',
        whereArgs: [plant.id],
      );
      return plant.id!;
    }
  }

  Future<List<DhwPlant>> getDhwPlants(int formId) async {
    final db = await database;
    final results = await db.query(
      'dhw_plants',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => DhwPlant.fromMap(map)).toList();
  }

  Future<void> deleteDhwPlant(int id) async {
    final db = await database;
    await db.delete('dhw_plants', where: 'id = ?', whereArgs: [id]);
  }

  // ========== FORM OPERATIONS ==========

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<int?> getCurrentFormId(String formType) async {
    final raw = await getSetting('$_currentFormKeyPrefix$formType');
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  Future<void> setCurrentFormId({
    required String formType,
    required int formId,
  }) async {
    await saveSetting('$_currentFormKeyPrefix$formType', formId.toString());
  }

  Future<void> clearCurrentFormId(String formType) async {
    await deleteSetting('$_currentFormKeyPrefix$formType');
  }

  Future<List<Map<String, dynamic>>> getFormsIndex({
    required String formType,
    required List<String> statuses,
  }) async {
    final db = await database;
    final placeholders = List.filled(statuses.length, '?').join(',');
    return await db.query(
      'forms',
      columns: [
        'id',
        'form_type',
        'status',
        'created_at',
        'updated_at',
        'uuid',
      ],
      where: 'form_type = ? AND status IN ($placeholders)',
      whereArgs: [formType, ...statuses],
      orderBy: 'updated_at DESC',
    );
  }

  /// Save or update a form
  Future<int> saveForm({
    int? id,
    required String formType,
    required String status,
    required Map<String, dynamic> formData,
    String? uuid,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final data = {
      'form_type': formType,
      'status': status,
      'form_data': jsonEncode(formData),
      'updated_at': now,
    };

    if (id == null) {
      // Create new form
      data['created_at'] = now;
      final cleanedUuid = (uuid ?? '').trim();
      data['uuid'] = cleanedUuid.isNotEmpty ? cleanedUuid : _newUuidV4();
      return await db.insert('forms', data);
    } else {
      // Update existing form
      await db.update('forms', data, where: 'id = ?', whereArgs: [id]);
      return id;
    }
  }

  /// Get a form by ID
  Future<Map<String, dynamic>?> getForm(int id) async {
    final db = await database;
    final results = await db.query('forms', where: 'id = ?', whereArgs: [id]);

    if (results.isEmpty) return null;

    final form = Map<String, dynamic>.from(results.first);
    form['form_data'] = jsonDecode(form['form_data']);
    return form;
  }

  /// Get all forms of a specific type
  Future<List<Map<String, dynamic>>> getFormsByType(String formType) async {
    final db = await database;
    final results = await db.query(
      'forms',
      where: 'form_type = ?',
      whereArgs: [formType],
      orderBy: 'updated_at DESC',
    );

    return results.map((form) {
      final f = Map<String, dynamic>.from(form);
      f['form_data'] = jsonDecode(f['form_data']);
      return f;
    }).toList();
  }

  /// Get all unsent/open forms
  Future<List<Map<String, dynamic>>> getUnsentForms() async {
    final db = await database;
    final results = await db.query(
      'forms',
      where: 'status IN (?, ?)',
      whereArgs: ['draft', 'pending'],
      orderBy: 'updated_at DESC',
    );

    return results.map((form) {
      final f = Map<String, dynamic>.from(form);
      f['form_data'] = jsonDecode(f['form_data']);
      return f;
    }).toList();
  }

  /// Update a form's status and updated_at timestamp.
  Future<void> setFormStatus(int id, String status) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'forms',
      {'status': status, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a form and all its observations
  Future<void> deleteForm(int id) async {
    final db = await database;
    await db.delete('forms', where: 'id = ?', whereArgs: [id]);
  }

  // ========== OBSERVATION OPERATIONS ==========

  /// Save or update an observation
  Future<int> saveObservation({
    int? id,
    required int formId,
    required String questionReference,
    String? notes,
    List<String>? imagePaths,
    String? questionText,
    String? sectionName,
    int? assetId,
    String? assetType,
    String? assetMakeModel,
    bool isUnsafe = false,
    String? unsafeClassification,
    String? unsafeActionTaken,
    String? unsafeWarningNoticeImage,
    String? unsafeAfterImage,
    String? unsafeResidentReaction,
    String? unsafeReportedToClient,
    String? unsafeReportedInternally,
    String? unsafeCheckedBy,
    String? unsafeCheckedDate,
    String? unsafeSentVia,
    String? unsafeSentTo,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final data = {
      'form_id': formId,
      'attached_to_type': 'question',
      'attached_to_id': questionReference,
      'attached_to_path': null,
      'question_reference': questionReference,
      'notes': notes,
      'question_text': questionText,
      'section_name': sectionName,
      'asset_id': assetId,
      'asset_type': assetType,
      'asset_make_model': assetMakeModel,
      'is_unsafe': isUnsafe ? 1 : 0,
      'unsafe_classification': unsafeClassification,
      'unsafe_action_taken': unsafeActionTaken,
      'unsafe_warning_notice_image': unsafeWarningNoticeImage,
      'unsafe_after_image': unsafeAfterImage,
      'unsafe_resident_reaction': unsafeResidentReaction,
      'unsafe_reported_to_client': unsafeReportedToClient,
      'unsafe_reported_internally': unsafeReportedInternally,
      'unsafe_checked_by': unsafeCheckedBy,
      'unsafe_checked_date': unsafeCheckedDate,
      'unsafe_sent_via': unsafeSentVia,
      'unsafe_sent_to': unsafeSentTo,
      'updated_at': now,
    };

    int observationId;
    if (id == null) {
      // Create new observation
      data['created_at'] = now;
      observationId = await db.insert('observations', data);
    } else {
      // Update existing observation
      await db.update('observations', data, where: 'id = ?', whereArgs: [id]);
      observationId = id;

      // Delete old images for this observation
      await db.delete(
        'observation_images',
        where: 'observation_id = ?',
        whereArgs: [observationId],
      );
    }

    // Save image paths
    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (final path in imagePaths) {
        await db.insert('observation_images', {
          'observation_id': observationId,
          'image_path': path,
          'created_at': now,
        });
      }
    }

    return observationId;
  }

  /// Get an observation with its images
  Future<Map<String, dynamic>?> getObservation(
    int formId,
    String questionReference,
  ) async {
    final db = await database;

    // Get observation
    final observations = await db.query(
      'observations',
      where: 'form_id = ? AND attached_to_type = ? AND attached_to_id = ?',
      whereArgs: [formId, 'question', questionReference],
    );

    if (observations.isEmpty) return null;

    final observation = Map<String, dynamic>.from(observations.first);

    // Get associated images
    final images = await db.query(
      'observation_images',
      where: 'observation_id = ?',
      whereArgs: [observation['id']],
      orderBy: 'created_at ASC',
    );

    observation['images'] = images.map((img) => img['image_path']).toList();
    return observation;
  }

  /// Get an observation by ID
  Future<Map<String, dynamic>?> getObservationById(int observationId) async {
    final db = await database;

    // Get observation
    final observations = await db.query(
      'observations',
      where: 'id = ?',
      whereArgs: [observationId],
    );

    if (observations.isEmpty) return null;

    final observation = Map<String, dynamic>.from(observations.first);

    // Get associated images
    final images = await db.query(
      'observation_images',
      where: 'observation_id = ?',
      whereArgs: [observation['id']],
      orderBy: 'created_at ASC',
    );

    observation['images'] = images.map((img) => img['image_path']).toList();
    return observation;
  }

  /// Get all unsafe observations for a form
  Future<List<Map<String, dynamic>>> getUnsafeObservations(int formId) async {
    final db = await database;

    final observations = await db.query(
      'observations',
      where: 'form_id = ? AND is_unsafe = 1',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final obs in observations) {
      final observation = Map<String, dynamic>.from(obs);

      // Get associated images
      final images = await db.query(
        'observation_images',
        where: 'observation_id = ?',
        whereArgs: [observation['id']],
        orderBy: 'created_at ASC',
      );

      observation['images'] = images.map((img) => img['image_path']).toList();
      result.add(observation);
    }

    return result;
  }

  /// Get all observations for a form
  Future<List<Map<String, dynamic>>> getFormObservations(int formId) async {
    final db = await database;

    final observations = await db.query(
      'observations',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at ASC',
    );

    // Get images for each observation
    final result = <Map<String, dynamic>>[];
    for (final obs in observations) {
      final observation = Map<String, dynamic>.from(obs);
      final images = await db.query(
        'observation_images',
        where: 'observation_id = ?',
        whereArgs: [observation['id']],
        orderBy: 'created_at ASC',
      );
      observation['images'] = images.map((img) => img['image_path']).toList();
      result.add(observation);
    }

    return result;
  }

  /// Get all observations for a specific question in a form
  Future<List<Map<String, dynamic>>> getQuestionObservations(
    int formId,
    String questionReference,
  ) async {
    final db = await database;

    final observations = await db.query(
      'observations',
      where: 'form_id = ? AND attached_to_type = ? AND attached_to_id = ?',
      whereArgs: [formId, 'question', questionReference],
      orderBy: 'created_at ASC',
    );

    // Get images for each observation
    final result = <Map<String, dynamic>>[];
    for (final obs in observations) {
      final observation = Map<String, dynamic>.from(obs);
      final images = await db.query(
        'observation_images',
        where: 'observation_id = ?',
        whereArgs: [observation['id']],
        orderBy: 'created_at ASC',
      );
      observation['images'] = images.map((img) => img['image_path']).toList();
      result.add(observation);
    }

    return result;
  }

  /// Delete an observation and its images
  Future<void> deleteObservation(int id) async {
    final db = await database;
    await db.delete('observations', where: 'id = ?', whereArgs: [id]);
  }

  // ========== SETTINGS OPERATIONS ==========

  /// Save a setting value
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert('settings', {
      'key': key,
      'value': value,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get a specific setting value
  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  /// Get all settings as a map
  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final results = await db.query('settings');

    final settings = <String, String>{};
    for (final row in results) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }

  // ========== UNSAFE REPORTS OPERATIONS ==========

  /// Create or update an unsafe report
  Future<int> saveUnsafeReport({
    int? id,
    required int formId,
    String? actionTaken,
    String? warningNoticeImage,
    String? afterImage,
    String? reportedToClient,
    String? reportedInternally,
    required List<int> observationIds,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final data = {
      'form_id': formId,
      'action_taken': actionTaken,
      'warning_notice_image': warningNoticeImage,
      'after_image': afterImage,
      'reported_to_client': reportedToClient,
      'reported_internally': reportedInternally,
      'updated_at': now,
    };

    int reportId;
    if (id == null) {
      // Create new report
      data['created_at'] = now;
      reportId = await db.insert('unsafe_reports', data);
    } else {
      // Update existing report
      await db.update('unsafe_reports', data, where: 'id = ?', whereArgs: [id]);
      reportId = id;

      // Delete old observation links
      await db.delete(
        'report_observations',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
    }

    // Link observations to report
    for (final obsId in observationIds) {
      await db.insert('report_observations', {
        'report_id': reportId,
        'observation_id': obsId,
      });
    }

    return reportId;
  }

  /// Get all unsafe reports for a form
  Future<List<Map<String, dynamic>>> getUnsafeReports(int formId) async {
    final db = await database;

    final reports = await db.query(
      'unsafe_reports',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final report in reports) {
      final reportMap = Map<String, dynamic>.from(report);

      // Get linked observations
      final obsLinks = await db.query(
        'report_observations',
        where: 'report_id = ?',
        whereArgs: [report['id']],
      );

      final observationIds = obsLinks
          .map((link) => link['observation_id'])
          .toList();
      reportMap['observation_ids'] = observationIds;
      reportMap['observation_count'] = observationIds.length;

      result.add(reportMap);
    }

    return result;
  }

  /// Get a single unsafe report with full details
  Future<Map<String, dynamic>?> getUnsafeReport(int reportId) async {
    final db = await database;

    final reports = await db.query(
      'unsafe_reports',
      where: 'id = ?',
      whereArgs: [reportId],
    );

    if (reports.isEmpty) return null;

    final report = Map<String, dynamic>.from(reports.first);

    // Get linked observations with full details
    final obsLinks = await db.query(
      'report_observations',
      where: 'report_id = ?',
      whereArgs: [reportId],
    );

    final observations = <Map<String, dynamic>>[];
    for (final link in obsLinks) {
      final obsId = link['observation_id'] as int;
      final obs = await getObservationById(obsId);
      if (obs != null) {
        observations.add(obs);
      }
    }

    report['observations'] = observations;
    return report;
  }

  /// Check if an observation is included in any report
  Future<bool> isObservationReported(int observationId) async {
    final db = await database;

    final links = await db.query(
      'report_observations',
      where: 'observation_id = ?',
      whereArgs: [observationId],
      limit: 1,
    );

    return links.isNotEmpty;
  }

  /// Get all unreported unsafe observations for a form
  Future<List<Map<String, dynamic>>> getUnreportedUnsafeObservations(
    int formId,
  ) async {
    // Get all unsafe observations
    final unsafeObs = await getUnsafeObservations(formId);

    // Filter out those that are already in reports
    final unreported = <Map<String, dynamic>>[];
    for (final obs in unsafeObs) {
      final isReported = await isObservationReported(obs['id'] as int);
      if (!isReported) {
        unreported.add(obs);
      }
    }

    return unreported;
  }

  /// Delete an unsafe report
  Future<void> deleteUnsafeReport(int reportId) async {
    final db = await database;
    await db.delete('unsafe_reports', where: 'id = ?', whereArgs: [reportId]);
    // report_observations will be deleted automatically due to CASCADE
  }

  // ========== ASSET TYPE OPERATIONS ==========

  /// Save or update an asset type
  Future<int> saveAssetType({
    int? id,
    required String assetType,
    required String domesticCommercial,
    int? expectedServiceLife,
    String? baseValue,
    double? valueModifier,
    String? imagePath,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final assetTypeData = {
      'asset_type': assetType,
      'domestic_commercial': domesticCommercial,
      'expected_service_life': expectedServiceLife,
      'base_value': baseValue,
      'value_modifier': valueModifier,
      'image_path': imagePath,
      'updated_at': now,
    };

    if (id == null) {
      assetTypeData['created_at'] = now;
      return await db.insert('asset_types', assetTypeData);
    } else {
      await db.update(
        'asset_types',
        assetTypeData,
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
  }

  /// Get all asset types
  Future<List<Map<String, dynamic>>> getAssetTypes() async {
    final db = await database;
    return await db.query('asset_types', orderBy: 'asset_type ASC');
  }

  /// Get a specific asset type by ID
  Future<Map<String, dynamic>?> getAssetType(int id) async {
    final db = await database;
    final results = await db.query(
      'asset_types',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Delete an asset type
  Future<void> deleteAssetType(int id) async {
    final db = await database;
    await db.delete('asset_types', where: 'id = ?', whereArgs: [id]);
  }

  // ========== PLANT ROOM OPERATIONS ==========

  /// Save or update a plant room
  Future<int> savePlantRoom({
    int? id,
    required int formId,
    String? location,
    List<String>? accessImagePaths,
    List<String>? internalImagePaths,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final plantRoomData = {
      'form_id': formId,
      'location': location,
      'updated_at': now,
    };

    if (id == null) {
      plantRoomData['created_at'] = now;
      id = await db.insert('plant_rooms', plantRoomData);
    } else {
      await db.update(
        'plant_rooms',
        plantRoomData,
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // Handle access images
    if (accessImagePaths != null) {
      await db.delete(
        'plant_room_images',
        where: 'plant_room_id = ? AND image_type = ?',
        whereArgs: [id, 'access'],
      );

      for (final imagePath in accessImagePaths) {
        await db.insert('plant_room_images', {
          'plant_room_id': id,
          'image_type': 'access',
          'image_path': imagePath,
          'created_at': now,
        });
      }
    }

    // Handle internal images
    if (internalImagePaths != null) {
      await db.delete(
        'plant_room_images',
        where: 'plant_room_id = ? AND image_type = ?',
        whereArgs: [id, 'internal'],
      );

      for (final imagePath in internalImagePaths) {
        await db.insert('plant_room_images', {
          'plant_room_id': id,
          'image_type': 'internal',
          'image_path': imagePath,
          'created_at': now,
        });
      }
    }

    return id;
  }

  /// Get all plant rooms for a form
  Future<List<Map<String, dynamic>>> getPlantRooms(int formId) async {
    final db = await database;

    final plantRooms = await db.query(
      'plant_rooms',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at ASC',
    );

    // Load images for each plant room and create mutable copies
    final result = <Map<String, dynamic>>[];
    for (final plantRoom in plantRooms) {
      final id = plantRoom['id'] as int;

      final accessImages = await db.query(
        'plant_room_images',
        where: 'plant_room_id = ? AND image_type = ?',
        whereArgs: [id, 'access'],
        orderBy: 'created_at ASC',
      );

      final internalImages = await db.query(
        'plant_room_images',
        where: 'plant_room_id = ? AND image_type = ?',
        whereArgs: [id, 'internal'],
        orderBy: 'created_at ASC',
      );

      // Create mutable copy and add images
      final mutablePlantRoom = Map<String, dynamic>.from(plantRoom);
      mutablePlantRoom['accessImages'] = accessImages
          .map((img) => img['image_path'] as String)
          .toList();
      mutablePlantRoom['internalImages'] = internalImages
          .map((img) => img['image_path'] as String)
          .toList();

      result.add(mutablePlantRoom);
    }

    return result;
  }

  /// Get a single plant room by ID
  Future<Map<String, dynamic>?> getPlantRoom(int id) async {
    final db = await database;

    final results = await db.query(
      'plant_rooms',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final plantRoom = Map<String, dynamic>.from(results.first);

    final accessImages = await db.query(
      'plant_room_images',
      where: 'plant_room_id = ? AND image_type = ?',
      whereArgs: [id, 'access'],
      orderBy: 'created_at ASC',
    );

    final internalImages = await db.query(
      'plant_room_images',
      where: 'plant_room_id = ? AND image_type = ?',
      whereArgs: [id, 'internal'],
      orderBy: 'created_at ASC',
    );

    plantRoom['accessImages'] = accessImages
        .map((img) => img['image_path'] as String)
        .toList();
    plantRoom['internalImages'] = internalImages
        .map((img) => img['image_path'] as String)
        .toList();

    return plantRoom;
  }

  /// Delete a plant room
  Future<void> deletePlantRoom(int id) async {
    final db = await database;
    await db.delete('plant_rooms', where: 'id = ?', whereArgs: [id]);
    // Images and responses will be automatically deleted via CASCADE
  }

  /// Save plant room response (subsection question answer)
  Future<void> savePlantRoomResponse({
    required int plantRoomId,
    required String questionKey,
    String? answerValue,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert('plant_room_responses', {
      'plant_room_id': plantRoomId,
      'question_key': questionKey,
      'answer_value': answerValue,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Save multiple plant room responses at once
  Future<void> savePlantRoomResponses({
    required int plantRoomId,
    required Map<String, String?> responses,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final entry in responses.entries) {
      batch.insert('plant_room_responses', {
        'plant_room_id': plantRoomId,
        'question_key': entry.key,
        'answer_value': entry.value,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Get all responses for a plant room
  Future<Map<String, String?>> getPlantRoomResponses(int plantRoomId) async {
    final db = await database;

    final results = await db.query(
      'plant_room_responses',
      where: 'plant_room_id = ?',
      whereArgs: [plantRoomId],
    );

    final responses = <String, String?>{};
    for (final row in results) {
      responses[row['question_key'] as String] = row['answer_value'] as String?;
    }

    return responses;
  }

  /// Delete all responses for a plant room
  Future<void> deletePlantRoomResponses(int plantRoomId) async {
    final db = await database;
    await db.delete(
      'plant_room_responses',
      where: 'plant_room_id = ?',
      whereArgs: [plantRoomId],
    );
  }

  // ========== ASSET OPERATIONS ==========

  /// Save or update an asset
  Future<int> saveAsset({
    int? id,
    required int formId,
    required int assetTypeId,
    String? assetMake,
    String? assetModel,
    String? location,
    int? estimateAge,
    String? operational,
    String? status,
    String? visualCondition,
    List<String>? imagePaths,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final assetData = {
      'form_id': formId,
      'asset_type_id': assetTypeId,
      'asset_make': assetMake,
      'asset_model': assetModel,
      'location': location,
      'estimate_age': estimateAge,
      'operational': operational,
      'status': status,
      'visual_condition': visualCondition,
      'updated_at': now,
    };

    if (id == null) {
      assetData['created_at'] = now;
      id = await db.insert('assets', assetData);
    } else {
      await db.update('assets', assetData, where: 'id = ?', whereArgs: [id]);
    }

    // Handle images
    if (imagePaths != null) {
      // Delete existing images
      await db.delete('asset_images', where: 'asset_id = ?', whereArgs: [id]);

      // Insert new images
      for (final imagePath in imagePaths) {
        await db.insert('asset_images', {
          'asset_id': id,
          'image_path': imagePath,
          'created_at': now,
        });
      }
    }

    return id;
  }

  /// Get all assets for a form
  Future<List<Map<String, dynamic>>> getAssets(int formId) async {
    final db = await database;
    final assets = await db.query(
      'assets',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );

    // Load asset type and images for each asset
    final List<Map<String, dynamic>> result = [];
    for (final asset in assets) {
      final assetId = asset['id'] as int;
      final assetTypeId = asset['asset_type_id'] as int;

      // Create a mutable copy of the asset
      final mutableAsset = Map<String, dynamic>.from(asset);

      // Get asset type details
      final assetType = await getAssetType(assetTypeId);
      mutableAsset['asset_type_details'] = assetType;

      // Get images
      final images = await db.query(
        'asset_images',
        where: 'asset_id = ?',
        whereArgs: [assetId],
        orderBy: 'created_at ASC',
      );
      mutableAsset['images'] = images.map((img) => img['image_path']).toList();

      result.add(mutableAsset);
    }

    return result;
  }

  /// Get a specific asset by ID
  Future<Map<String, dynamic>?> getAsset(int id) async {
    final db = await database;
    final results = await db.query('assets', where: 'id = ?', whereArgs: [id]);

    if (results.isEmpty) return null;

    final asset = Map<String, dynamic>.from(results.first);
    final assetTypeId = asset['asset_type_id'] as int;

    // Get asset type details
    final assetType = await getAssetType(assetTypeId);
    asset['asset_type_details'] = assetType;

    // Get images
    final images = await db.query(
      'asset_images',
      where: 'asset_id = ?',
      whereArgs: [id],
      orderBy: 'created_at ASC',
    );
    asset['images'] = images.map((img) => img['image_path']).toList();

    return asset;
  }

  /// Delete an asset
  Future<void> deleteAsset(int id) async {
    final db = await database;
    await db.delete('assets', where: 'id = ?', whereArgs: [id]);
  }

  /// Check if a form has assets
  Future<bool> formHasAssets(int formId) async {
    final db = await database;
    final result = await db.query(
      'assets',
      where: 'form_id = ?',
      whereArgs: [formId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ========== HEAT METER OPERATIONS ==========

  Future<int> saveHeatMeter(HeatMeter meter) async {
    final db = await database;
    final map = meter.toMap();

    if (meter.id == null) {
      return await db.insert('heat_meters', map);
    } else {
      await db.update(
        'heat_meters',
        map,
        where: 'id = ?',
        whereArgs: [meter.id],
      );
      return meter.id!;
    }
  }

  Future<List<HeatMeter>> getHeatMeters(int formId) async {
    final db = await database;
    final results = await db.query(
      'heat_meters',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => HeatMeter.fromMap(map)).toList();
  }

  Future<HeatMeter?> getHeatMeterByRelatedAsset(
    int formId,
    String assetType,
    int assetId,
  ) async {
    final db = await database;
    final results = await db.query(
      'heat_meters',
      where: 'form_id = ? AND related_asset_type = ? AND related_asset_id = ?',
      whereArgs: [formId, assetType, assetId],
    );

    if (results.isEmpty) return null;
    return HeatMeter.fromMap(results.first);
  }

  Future<HeatMeter?> getHeatMeter(int id) async {
    final db = await database;
    final results = await db.query(
      'heat_meters',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return HeatMeter.fromMap(results.first);
  }

  Future<void> deleteHeatMeter(int id) async {
    final db = await database;
    await db.delete('heat_meters', where: 'id = ?', whereArgs: [id]);
  }

  // ========== PLATE HEAT EXCHANGER OPERATIONS ==========

  Future<int> savePlateHeatExchanger(PlateHeatExchanger phex) async {
    final db = await database;
    final map = phex.toMap();

    if (phex.id == null) {
      return await db.insert('plate_heat_exchangers', map);
    } else {
      await db.update(
        'plate_heat_exchangers',
        map,
        where: 'id = ?',
        whereArgs: [phex.id],
      );
      return phex.id!;
    }
  }

  Future<List<PlateHeatExchanger>> getPlateHeatExchangers(int formId) async {
    final db = await database;
    final results = await db.query(
      'plate_heat_exchangers',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => PlateHeatExchanger.fromMap(map)).toList();
  }

  Future<void> deletePlateHeatExchanger(int id) async {
    final db = await database;
    await db.delete('plate_heat_exchangers', where: 'id = ?', whereArgs: [id]);
  }

  // ========== HEAT GENERATOR OPERATIONS ==========

  Future<int> saveHeatGenerator(HeatGenerator generator) async {
    final db = await database;
    final map = generator.toMap();

    if (generator.id == null) {
      return await db.insert('heat_generators', map);
    } else {
      await db.update(
        'heat_generators',
        map,
        where: 'id = ?',
        whereArgs: [generator.id],
      );
      return generator.id!;
    }
  }

  Future<List<HeatGenerator>> getHeatGenerators(int formId) async {
    final db = await database;
    final results = await db.query(
      'heat_generators',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => HeatGenerator.fromMap(map)).toList();
  }

  Future<void> deleteHeatGenerator(int id) async {
    final db = await database;
    await db.delete('heat_generators', where: 'id = ?', whereArgs: [id]);
  }

  // ========== GENERIC COLLECTION OPERATIONS ==========

  /// Get all items from a collection
  Future<List<Map<String, dynamic>>> getCollectionItems(
    String tableName,
  ) async {
    final db = await database;
    return await db.query(tableName, orderBy: 'name ASC');
  }

  /// Save or update a collection item
  Future<int> saveCollectionItem({
    required String tableName,
    int? id,
    required String name,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final data = {'name': name, 'updated_at': now};

    if (id == null) {
      data['created_at'] = now;
      return await db.insert(tableName, data);
    } else {
      await db.update(tableName, data, where: 'id = ?', whereArgs: [id]);
      return id;
    }
  }

  /// Delete a collection item
  Future<void> deleteCollectionItem(String tableName, int id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // ========== CONVENIENCE METHODS (Backward Compatibility) ==========

  /// Get all clients
  Future<List<Map<String, dynamic>>> getClients() async {
    return getCollectionItems('clients');
  }

  /// Save or update a client
  Future<int> saveClient({int? id, required String name}) async {
    return saveCollectionItem(tableName: 'clients', id: id, name: name);
  }

  /// Delete a client
  Future<void> deleteClient(int id) async {
    return deleteCollectionItem('clients', id);
  }

  /// Replace all clients with the supplied list (used when syncing from portal).
  Future<void> replaceClients(List<String> names) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final unique = <String>{};
    final cleaned = <String>[];
    for (final n in names) {
      final t = n.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      if (unique.add(key)) cleaned.add(t);
    }
    cleaned.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await db.transaction((txn) async {
      await txn.delete('clients');
      for (final name in cleaned) {
        await txn.insert('clients', {
          'name': name,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  /// Get all property types
  Future<List<Map<String, dynamic>>> getPropertyTypes() async {
    return getCollectionItems('property_types');
  }

  /// Save or update a property type
  Future<int> savePropertyType({int? id, required String name}) async {
    return saveCollectionItem(tableName: 'property_types', id: id, name: name);
  }

  /// Delete a property type
  Future<void> deletePropertyType(int id) async {
    return deleteCollectionItem('property_types', id);
  }

  // ========== INPUT SUGGESTIONS OPERATIONS ==========

  /// Get suggestions for a field with optional filter context
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String query,
    Map<String, String>? filterContext,
    int limit = 10,
  }) async {
    final db = await database;

    // Build filter context string (null if no context)
    final contextStr = filterContext != null && filterContext.isNotEmpty
        ? jsonEncode(filterContext)
        : null;

    developer.log(
      '[AutoComplete] getSuggestions - field: $fieldName, query: $query, context: $contextStr',
    );

    // Query with case-insensitive LIKE and context matching
    // Use DISTINCT on lowercase value to avoid duplicates
    final results = await db.rawQuery(
      '''
      SELECT DISTINCT LOWER(value) as value_lower, 
             (SELECT value FROM input_suggestions i2 
              WHERE LOWER(i2.value) = LOWER(i1.value) 
              AND i2.field_name = i1.field_name
              ${contextStr != null ? 'AND i2.filter_context = i1.filter_context' : 'AND i2.filter_context IS NULL'}
              ORDER BY i2.usage_count DESC, i2.last_used DESC 
              LIMIT 1) as value,
             SUM(usage_count) as total_usage, 
             MAX(last_used) as latest_used
      FROM input_suggestions i1
      WHERE ${contextStr != null ? 'field_name = ? AND filter_context = ? AND LOWER(value) LIKE ?' : 'field_name = ? AND filter_context IS NULL AND LOWER(value) LIKE ?'}
      GROUP BY LOWER(value)
      ORDER BY total_usage DESC, latest_used DESC
      LIMIT ?
      ''',
      contextStr != null
          ? [fieldName, contextStr, '${query.toLowerCase()}%', limit]
          : [fieldName, '${query.toLowerCase()}%', limit],
    );

    developer.log(
      '[AutoComplete] getSuggestions - found ${results.length} results: ${results.map((r) => r['value']).toList()}',
    );

    return results.map((r) => r['value'] as String).toList();
  }

  /// Save or update a suggestion (increments usage count if exists)
  Future<void> saveSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) async {
    if (value.trim().isEmpty) return;

    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Build filter context string (null if no context)
    final contextStr = filterContext != null && filterContext.isNotEmpty
        ? jsonEncode(filterContext)
        : null;

    developer.log(
      '[AutoComplete] saveSuggestion - field: $fieldName, value: $value, context: $contextStr',
    );

    // Check if suggestion already exists
    final existing = await db.query(
      'input_suggestions',
      where: contextStr != null
          ? 'field_name = ? AND value = ? AND filter_context = ?'
          : 'field_name = ? AND value = ? AND filter_context IS NULL',
      whereArgs: contextStr != null
          ? [fieldName, value, contextStr]
          : [fieldName, value],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update existing suggestion
      final id = existing.first['id'] as int;
      final currentCount = existing.first['usage_count'] as int;
      await db.update(
        'input_suggestions',
        {'usage_count': currentCount + 1, 'last_used': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // Insert new suggestion
      await db.insert('input_suggestions', {
        'field_name': fieldName,
        'value': value,
        'filter_context': contextStr,
        'usage_count': 1,
        'last_used': now,
        'created_at': now,
      });
    }
  }

  /// Clean up old unused suggestions (older than 6 months, used less than 2 times)
  Future<void> cleanupOldSuggestions() async {
    final db = await database;
    final sixMonthsAgo = DateTime.now()
        .subtract(const Duration(days: 180))
        .toIso8601String();

    await db.delete(
      'input_suggestions',
      where: 'last_used < ? AND usage_count < 2',
      whereArgs: [sixMonthsAgo],
    );
  }

  /// Delete all suggestions matching a specific value (case-insensitive)
  Future<void> deleteSuggestion({
    required String fieldName,
    required String value,
    Map<String, String>? filterContext,
  }) async {
    final db = await database;

    // Build filter context string (null if no context)
    final contextStr = filterContext != null && filterContext.isNotEmpty
        ? jsonEncode(filterContext)
        : null;

    // Delete all matching suggestions (case-insensitive)
    await db.delete(
      'input_suggestions',
      where: contextStr != null
          ? 'field_name = ? AND LOWER(value) = LOWER(?) AND filter_context = ?'
          : 'field_name = ? AND LOWER(value) = LOWER(?) AND filter_context IS NULL',
      whereArgs: contextStr != null
          ? [fieldName, value, contextStr]
          : [fieldName, value],
    );
  }

  // ========== COMMUNAL CONTROLS OPERATIONS ==========

  Future<int> saveCommunalControl(CommunalControl item) async {
    final db = await database;
    if (item.id == null) {
      return await db.insert('communal_controls', item.toMap());
    } else {
      await db.update(
        'communal_controls',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      return item.id!;
    }
  }

  Future<List<CommunalControl>> getCommunalControls(int formId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'communal_controls',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => CommunalControl.fromMap(maps[i]));
  }

  Future<void> deleteCommunalControl(int id) async {
    final db = await database;
    await db.delete('communal_controls', where: 'id = ?', whereArgs: [id]);
  }

  // ========== DWELLING INSPECTIONS OPERATIONS ==========

  Future<int> saveDwellingInspection(DwellingInspection item) async {
    final db = await database;
    if (item.id == null) {
      return await db.insert('dwelling_inspections', item.toMap());
    } else {
      await db.update(
        'dwelling_inspections',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      return item.id!;
    }
  }

  Future<List<DwellingInspection>> getDwellingInspections(int formId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dwelling_inspections',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'created_at DESC',
    );
    return List.generate(
      maps.length,
      (i) => DwellingInspection.fromMap(maps[i]),
    );
  }

  Future<void> deleteDwellingInspection(int id) async {
    final db = await database;
    await db.delete('dwelling_inspections', where: 'id = ?', whereArgs: [id]);
  }

  // ========== UTILITY OPERATIONS ==========

  /// Clear all data (useful for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('asset_observation_images');
    await db.delete('asset_observations');
    await db.delete('asset_images');
    await db.delete('assets');
    await db.delete('observation_images');
    await db.delete('observations');
    await db.delete('forms');
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ========== SETTINGS / APP STATE ==========

  Future<DateTime?> getInstallDate() async {
    final value = await getSetting('app_install_date');
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> setInstallDate(DateTime value) async {
    await saveSetting('app_install_date', value.toUtc().toIso8601String());
  }
}
