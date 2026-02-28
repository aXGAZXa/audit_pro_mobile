class UserProfile {
  const UserProfile({
    required this.email,
    required this.displayName,
    this.companyName,
  });

  final String email;
  final String displayName;
  final String? companyName;
}
