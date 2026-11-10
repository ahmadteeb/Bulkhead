import 'dart:async';
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
  Timer? _startupTimer;
  HttpClient? _client;
  Future<void>? _checkFuture;

  UpdateNotifier() : super(const AsyncValue.data(null)) {
    // Automatically check for updates 3 seconds after app start
    _startupTimer = Timer(const Duration(seconds: 3), () {
      checkForUpdates();
    });
  }

  Future<void> checkForUpdates({bool forceUserCheck = false}) {
    if (!mounted) return Future.value();
    return _checkFuture ??= _checkForUpdates(
      forceUserCheck: forceUserCheck,
    ).whenComplete(() => _checkFuture = null);
  }

  Future<void> _checkForUpdates({required bool forceUserCheck}) async {
    if (!mounted) return;
    _startupTimer?.cancel();
    await AppVersion.init();
    if (!mounted) return;
    if (!forceUserCheck && state.valueOrNull?.hasUpdate == true) {
      return;
    }

    state = const AsyncValue.loading();

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      _client = client;
      client.userAgent = 'Bulkhead-Flutter-App';

      final uri = Uri.parse(AppVersion.latestReleaseUrl);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github+json');

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw HttpException('Update check failed: HTTP ${response.statusCode}');
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final json = jsonDecode(body) as Map<String, dynamic>;

      final rawTag =
          json['tag_name'] as String? ?? 'v${AppVersion.currentVersion}';
      final latestVersion = rawTag.replaceFirst(RegExp(r'^[vV]'), '').trim();
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

      final hasUpdate = AppVersion.isNewer(
        latestVersion,
        AppVersion.currentVersion,
      );

      state = AsyncValue.data(
        UpdateInfoModel(
          latestVersion: latestVersion,
          currentVersion: AppVersion.currentVersion,
          hasUpdate: hasUpdate,
          releaseNotes: bodyText,
          releaseHtmlUrl: htmlUrl,
          assets: assets,
        ),
      );
    } catch (e, stack) {
      if (mounted) state = AsyncValue.error(e, stack);
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _client?.close(force: true);
    super.dispose();
  }
}
