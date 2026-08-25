import 'dart:io';

class UpdateAssetModel {
  final String name;
  final String downloadUrl;

  UpdateAssetModel({required this.name, required this.downloadUrl});
}

class UpdateInfoModel {
  final String latestVersion;
  final String currentVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final String releaseHtmlUrl;
  final List<UpdateAssetModel> assets;

  UpdateInfoModel({
    required this.latestVersion,
    required this.currentVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.releaseHtmlUrl,
    required this.assets,
  });

  UpdateAssetModel? get platformAsset {
    if (assets.isEmpty) return null;
    if (Platform.isMacOS) {
      return assets.firstWhere(
        (a) => a.name.endsWith('.dmg') || a.name.contains('macos'),
        orElse: () => assets.first,
      );
    } else if (Platform.isWindows) {
      return assets.firstWhere(
        (a) => a.name.endsWith('.zip') && a.name.contains('windows'),
        orElse: () => assets.first,
      );
    } else if (Platform.isLinux) {
      return assets.firstWhere(
        (a) =>
            a.name.endsWith('.deb') ||
            a.name.endsWith('.pkg.tar.zst') ||
            a.name.endsWith('.rpm') ||
            a.name.contains('linux'),
        orElse: () => assets.first,
      );
    }
    return assets.first;
  }
}
