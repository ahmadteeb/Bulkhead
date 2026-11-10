import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static PackageInfo? _info;

  static String get currentVersion =>
      _info?.version.isNotEmpty == true ? _info!.version : 'Unknown';
  static String get buildNumber => _info?.buildNumber ?? '';
  static String get fullVersionString =>
      buildNumber.isEmpty ? currentVersion : '$currentVersion+$buildNumber';

  static const String repoOwner = 'ahmadteeb';
  static const String repoName = 'Bulkhead';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  static bool isNewer(String latest, String current) {
    ({List<int> core, List<String> pre}) parse(String value) {
      final match = RegExp(
        r'^[vV]?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
      ).firstMatch(value.trim());
      if (match == null) throw const FormatException('Invalid release version');
      return (
        core: [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)],
        pre: match.group(4)?.split('.') ?? [],
      );
    }

    try {
      final a = parse(latest), b = parse(current);
      for (var i = 0; i < 3; i++) {
        if (a.core[i] != b.core[i]) return a.core[i] > b.core[i];
      }
      if (a.pre.isEmpty || b.pre.isEmpty) {
        return a.pre.isEmpty && b.pre.isNotEmpty;
      }
      for (var i = 0; i < a.pre.length && i < b.pre.length; i++) {
        final left = a.pre[i], right = b.pre[i];
        if (left == right) continue;
        final leftNumber = int.tryParse(left),
            rightNumber = int.tryParse(right);
        if (leftNumber != null && rightNumber != null) {
          return leftNumber > rightNumber;
        }
        if (leftNumber != null || rightNumber != null) {
          return rightNumber != null;
        }
        return left.compareTo(right) > 0;
      }
      return a.pre.length > b.pre.length;
    } on FormatException {
      return false;
    }
  }

  static Future<void> init() async {
    try {
      _info = await PackageInfo.fromPlatform();
    } catch (_) {}
  }
}
