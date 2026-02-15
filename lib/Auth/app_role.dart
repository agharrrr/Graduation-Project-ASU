enum AppRole { user, organizer, admin }

extension AppRoleX on AppRole {
  String get value => name;

  static AppRole fromString(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'admin':
        return AppRole.admin;
      case 'organizer':
        return AppRole.organizer;
      case 'user':
      default:
        return AppRole.user;
    }
  }
}
