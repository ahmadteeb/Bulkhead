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

  UpdateAssetModel? get platformAsset =>
      assetForPlatform(Platform.operatingSystem);

  UpdateAssetModel? assetForPlatform(String platform) {
    final candidates = assets.where((asset) {
      final name = asset.name.toLowerCase();
      return switch (platform) {
        'macos' => name.endsWith('.dmg') || name.contains('macos'),
        'windows' => name.endsWith('.zip') && name.contains('windows'),
        'linux' =>
          name.contains('linux') ||
              name.endsWith('.deb') ||
              name.endsWith('.rpm') ||
              name.endsWith('.pkg.tar.zst'),
        _ => false,
      };
    }).toList();
    if (platform == 'linux') {
      final portable = candidates.where(
        (asset) => asset.name.toLowerCase().endsWith('.zip'),
      );
      if (portable.isNotEmpty) return portable.first;
    }
    if (platform == 'macos') {
      final diskImage = candidates.where(
        (asset) => asset.name.toLowerCase().endsWith('.dmg'),
      );
      if (diskImage.isNotEmpty) return diskImage.first;
    }
    return candidates.firstOrNull;
  }
}
