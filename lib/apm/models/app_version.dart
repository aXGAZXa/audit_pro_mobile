class AppVersion {
  const AppVersion({required this.name, required this.code});

  final String name;
  final int code;

  @override
  String toString() => '$name+$code';
}
