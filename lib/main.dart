import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'screens/config_screen.dart';
import 'screens/converter_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/tutorial_screen.dart';
import 'state/miner_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BtcMinerApp());
}

class BtcMinerApp extends StatelessWidget {
  const BtcMinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MinerController()..init(),
      child: MaterialApp(
        title: 'BTC Miner Fun',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _titles = [
    'Minage',
    'Labo',
    'Historique',
    'Convertir',
    'Reglages',
    'Guide'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text('B',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Text(_titles[_index],
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [
            DashboardScreen(),
            LabScreen(),
            HistoryScreen(),
            ConverterScreen(),
            ConfigScreen(),
            TutorialScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.amber.withOpacity(0.18),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
          ),
          child: NavigationBar(
            height: 66,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt_rounded, color: AppColors.amber),
                  label: 'Minage'),
              NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  selectedIcon:
                      Icon(Icons.science_rounded, color: AppColors.amber),
                  label: 'Labo'),
              NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon:
                      Icon(Icons.history_rounded, color: AppColors.amber),
                  label: 'Sessions'),
              NavigationDestination(
                  icon: Icon(Icons.euro_outlined),
                  selectedIcon:
                      Icon(Icons.euro_rounded, color: AppColors.amber),
                  label: 'Euros'),
              NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded, color: AppColors.amber),
                  label: 'Reglages'),
              NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: Icon(Icons.school_rounded, color: AppColors.amber),
                  label: 'Guide'),
            ],
          ),
        ),
      ),
    );
  }
}
