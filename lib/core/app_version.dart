import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static String _version = '1.0.0';
  static String _buildNumber = '1';

  static String get currentVersion => _version;
  static String get buildNumber => _buildNumber;
  static String get fullVersionString => '$_version+$_buildNumber';

  static const String repoOwner = 'ahmadteeb';
  static const String repoName = 'Bulkhead';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _version = info.version;
      }
      if (info.buildNumber.isNotEmpty) {
        _buildNumber = info.buildNumber;
      }
    } catch (_) {}
  }
}
