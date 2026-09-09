import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/about_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/equalizer_screen.dart';
import 'services/bluetooth_service.dart';
import 'services/equalizer_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothService()),
        ChangeNotifierProvider(create: (_) => EqualizerService()),
      ],
      child: const OpenHearablesApp(),
    ),
  );
}

class OpenHearablesApp extends StatelessWidget {
  const OpenHearablesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // True Material 3 Semantic Color System
    const seedColor = Color(0xFF006A6A); // Deep Teal / Audio Precision Seed

    return MaterialApp(
      title: 'Open Hearables',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        // Semantic Token Hierarchy
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 4,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
        ),
        switchTheme: SwitchThemeData(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Icon(Icons.check, size: 14);
            }
            return const Icon(Icons.close, size: 14);
          }),
        ),
      ),
      home: const AdaptiveMainScaffold(),
    );
  }
}

/// Adaptive M3 Scaffold: Switches between NavigationBar (compact)
/// and NavigationRail (medium/expanded windows).
class AdaptiveMainScaffold extends StatefulWidget {
  const AdaptiveMainScaffold({super.key});

  @override
  State<AdaptiveMainScaffold> createState() => _AdaptiveMainScaffoldState();
}

class _AdaptiveMainScaffoldState extends State<AdaptiveMainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _destinations = const [
    DashboardScreen(),
    EqualizerScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          // M3 Navigation Rail for Tablets / Foldables / Desktop
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Icon(
                      Icons.headphones,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.equalizer_outlined),
                      selectedIcon: Icon(Icons.equalizer),
                      label: Text('Equalizer'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shield_outlined),
                      selectedIcon: Icon(Icons.shield),
                      label: Text('Privacy'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _destinations,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // M3 Navigation Bar for Mobile Compact
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _destinations,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.equalizer_outlined),
                selectedIcon: Icon(Icons.equalizer),
                label: 'Equalizer',
              ),
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield),
                label: 'Privacy',
              ),
            ],
          ),
        );
      },
    );
  }
}
