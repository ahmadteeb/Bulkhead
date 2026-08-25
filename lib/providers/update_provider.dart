import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_version.dart';
import '../models/update_model.dart';

final updateCheckNotifierProvider =
    StateNotifierProvider<UpdateNotifier, AsyncValue<UpdateInfoModel?>>((ref) {
  return UpdateNotifier();
});

class UpdateNotifier extends StateNotifier<AsyncValue<UpdateInfoModel?>> {
  UpdateNotifier() : super(const AsyncValue.data(null)) {
    // Automatically check for updates 3 seconds after app start
    Future.delayed(const Duration(seconds: 3), () {
      checkForUpdates();
    });
  }

  Future<void> checkForUpdates({bool forceUserCheck = false}) async {
    await AppVersion.init();
    if (!forceUserCheck && state.value != null && state.value!.hasUpdate) {
      return;
    }

    state = const AsyncValue.loading();

    try {
      final client = HttpClient();
      client.userAgent = 'Bulkhead-Flutter-App';

      final uri = Uri.parse(AppVersion.latestReleaseUrl);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        state = AsyncValue.data(UpdateInfoModel(
          latestVersion: AppVersion.currentVersion,
          currentVersion: AppVersion.currentVersion,
          hasUpdate: false,
          releaseNotes: '',
          releaseHtmlUrl: AppVersion.releasesPageUrl,
          assets: [],
        ));
        return;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final rawTag = json['tag_name'] as String? ?? 'v${AppVersion.currentVersion}';
      final latestVersion = rawTag.replaceAll('v', '').trim();
      final bodyText = json['body'] as String? ?? '';
      final htmlUrl = json['html_url'] as String? ?? AppVersion.releasesPageUrl;

      final assetsJson = json['assets'] as List<dynamic>? ?? [];
      final assets = assetsJson.map((a) {
        final m = a as Map<String, dynamic>;
        return UpdateAssetModel(
          name: m['name'] as String? ?? '',
          downloadUrl: m['browser_download_url'] as String? ?? '',
        );
      }).toList();

      final hasUpdate = _isVersionNewer(latestVersion, AppVersion.currentVersion);

      state = AsyncValue.data(UpdateInfoModel(
        latestVersion: latestVersion,
        currentVersion: AppVersion.currentVersion,
        hasUpdate: hasUpdate,
        releaseNotes: bodyText,
        releaseHtmlUrl: htmlUrl,
        assets: assets,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  bool _isVersionNewer(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return latest != current;
    }
  }
}
