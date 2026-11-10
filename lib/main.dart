import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/compose/compose_screen.dart';
import 'features/containers/container_detail_screen.dart';
import 'features/containers/containers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/images/images_screen.dart';
import 'features/networks/networks_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/volumes/volumes_screen.dart';
import 'models/container_model.dart';
import 'providers/events_provider.dart';
import 'providers/connection_status_provider.dart';
import 'theme/design_tokens.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_sidebar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const ProviderScope(child: BulkheadApp()));
}

class BulkheadApp extends ConsumerWidget {
  const BulkheadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      title: 'Bulkhead',
      debugShowCheckedModeBanner: true,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainLayoutScreen(),
    );
  }
}

class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  int _selectedIndex = 0;
  ContainerModel? _selectedContainer;

  @override
  Widget build(BuildContext context) {
    // Keep real-time Docker events active across all screens
    ref.watch(recentEventsListProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                AppSidebar(
                  compact: compact,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() {
                    _selectedIndex = index;
                    _selectedContainer = null;
                  }),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.pagePadding,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(context),
                          border: Border(
                            bottom: BorderSide(color: scheme.outline),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.dns_outlined,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Docker',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.chevron_right, size: 14),
                            ),
                            Expanded(
                              child: Text(
                                AppSidebar.items[_selectedIndex].title,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh connection',
                              onPressed: () => ref
                                  .read(connectionStatusProvider.notifier)
                                  .checkConnection(),
                              icon: const Icon(Icons.sync_rounded, size: 20),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip:
                                  'Switch to ${AppColors.isDark(context) ? 'light' : 'dark'} theme',
                              onPressed: () =>
                                  ref
                                      .read(appThemeModeProvider.notifier)
                                      .state = AppColors.isDark(context)
                                  ? ThemeMode.light
                                  : ThemeMode.dark,
                              icon: Icon(
                                AppColors.isDark(context)
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _buildCurrentScreen()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen() {
    if (_selectedIndex == 1 && _selectedContainer != null) {
      return ContainerDetailScreen(
        container: _selectedContainer!,
        onBack: () => setState(() => _selectedContainer = null),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return ContainersScreen(
          onSelectContainer: (container) {
            setState(() {
              _selectedContainer = container;
            });
          },
        );
      case 2:
        return const ImagesScreen();
      case 3:
        return const ComposeScreen();
      case 4:
        return const VolumesScreen();
      case 5:
        return const NetworksScreen();
      case 6:
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }
}
