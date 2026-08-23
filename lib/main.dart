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
      title: 'Bulkhead - Flutter Docker Manager',
      debugShowCheckedModeBanner: false,
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

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          AppSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                _selectedContainer = null;
              });
            },
          ),

          // Main View Content Area
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _buildCurrentScreen(),
            ),
          ),
        ],
      ),
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
