import 'package:bulkhead/core/app_version.dart';
import 'package:bulkhead/models/update_model.dart';
import 'package:bulkhead/providers/containers_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release comparison respects prereleases, numeric identifiers and build metadata',
    () {
      for (final (latest, current, expected) in [
        ('2.0.0', '1.9.9', true),
        ('1.0.0', '1.0.0-rc.1', true),
        ('1.0.0-beta', '1.0.0', false),
        ('1.0.0-rc.10', '1.0.0-rc.2', true),
        ('1.0.0-alpha.beta', '1.0.0-alpha.1', true),
        ('1.0.0+build2', '1.0.0+build1', false),
        ('v1.2.3', '1.2.2', true),
        ('not-a-version', '1.0.0', false),
      ]) {
        expect(
          AppVersion.isNewer(latest, current),
          expected,
          reason: '$latest / $current',
        );
      }
    },
  );

  test('download selection never falls back to another platform', () {
    final info = UpdateInfoModel(
      latestVersion: '1.0.1',
      currentVersion: '1.0.0',
      hasUpdate: true,
      releaseNotes: '',
      releaseHtmlUrl: '',
      assets: [
        UpdateAssetModel(name: 'bulkhead_macos.dmg', downloadUrl: 'mac'),
        UpdateAssetModel(name: 'bulkhead.deb', downloadUrl: 'deb'),
        UpdateAssetModel(
          name: 'bulkhead-linux-x64.zip',
          downloadUrl: 'portable',
        ),
      ],
    );
    expect(info.assetForPlatform('windows'), isNull);
    expect(info.assetForPlatform('linux')?.downloadUrl, 'portable');
    expect(info.assetForPlatform('macos')?.downloadUrl, 'mac');
  });

  test(
    'storage counts shared image layers once and ignores unknown negative sizes',
    () {
      final result = parseSystemDiskUsage({
        'LayersSize': 100,
        'Images': [
          {'Size': 100},
          {'Size': 100},
        ],
        'Containers': [
          {'SizeRw': 20},
          {'SizeRw': -1},
        ],
        'Volumes': [
          {
            'UsageData': {'Size': -1},
          },
          {
            'UsageData': {'Size': 30},
          },
        ],
      });
      expect(result, {
        'images': 100,
        'containers': 20,
        'volumes': 30,
        'total': 150,
      });
    },
  );
}
