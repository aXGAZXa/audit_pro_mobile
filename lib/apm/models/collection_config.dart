/// Configuration for app collections that can be managed and seeded
class CollectionConfig {
  final String name;
  final String tableName;
  final String displayName;
  final String singularName;
  final List<String> seedData;

  const CollectionConfig({
    required this.name,
    required this.tableName,
    required this.displayName,
    required this.singularName,
    required this.seedData,
  });
}

/// All app collections configuration
class AppCollections {
  static const clients = CollectionConfig(
    name: 'clients',
    tableName: 'clients',
    displayName: 'Clients',
    singularName: 'Client',
    seedData: ['Client A', 'Client B', 'Client C', 'Other'],
  );

  static const propertyTypes = CollectionConfig(
    name: 'property_types',
    tableName: 'property_types',
    displayName: 'Property Types',
    singularName: 'Property Type',
    seedData: [
      'Assisted Living',
      'Care Home',
      'Community Centre',
      'Factory',
      'High Rise Residential',
      'Independent Living',
      'Large Commercial Unit',
      'Office',
      'School',
      'Small Commercial Unit',
      'Warehouse',
      "Women's Shelter",
      'Other',
    ],
  );

  static const assetStatuses = CollectionConfig(
    name: 'asset_statuses',
    tableName: 'asset_statuses',
    displayName: 'Asset Statuses',
    singularName: 'Asset Status',
    seedData: [
      'Operational',
      'Isolated',
      'Corrosion Evident',
      'Leaking',
      'Faul State',
      'Unsafe',
    ],
  );

  /// List of all collections available in the app
  static const List<CollectionConfig> all = [
    clients,
    propertyTypes,
    assetStatuses,
  ];

  /// Get collection by name
  static CollectionConfig? getByName(String name) {
    try {
      return all.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }
}
