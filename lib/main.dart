import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'core/app_version.dart';
import 'core/platform_profile.dart';
import 'screens/config_screen.dart';
import 'screens/converter_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/screensaver_screen.dart';
import 'screens/tutorial_screen.dart';
import 'state/miner_controller.dart';
import 'widgets/futuristic_background.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.abyss,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
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
  final FocusNode _shortcutFocus = FocusNode();

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  /// Les raccourcis n'utilisent que des touches qui ne servent jamais a la
  /// saisie : pas de risque de declencher le minage en tapant une adresse.
  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) {
    final m = context.read<MinerController>();
    return {
      const SingleActivator(LogicalKeyboardKey.f5): m.toggle,
      const SingleActivator(LogicalKeyboardKey.f11): () =>
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ScreensaverScreen()),
          ),
      for (var i = 0; i < 6; i++)
        SingleActivator(
          [
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
            LogicalKeyboardKey.digit3,
            LogicalKeyboardKey.digit4,
            LogicalKeyboardKey.digit5,
            LogicalKeyboardKey.digit6,
          ][i],
          control: true,
        ): () => setState(() => _index = i),
    };
  }

  int _index = 0;

  static const _titles = [
    'Minage',
    'Labo',
    'Historique',
    'Convertir',
    'Reglages',
    'Guide'
  ];

  static const _subtitles = [
    'REACTOR CORE',
    'HASH LAB',
    'SESSION ARCHIVE',
    'MARKET LINK',
    'SYSTEM CONFIG',
    'KNOWLEDGE BASE',
  ];

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcuts(context),
      child: Focus(
        autofocus: true,
        focusNode: _shortcutFocus,
        child: _buildShell(context),
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: 16,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.abyss.withOpacity(.98),
                AppColors.night.withOpacity(.90),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: AppColors.line.withOpacity(.55)),
            ),
          ),
        ),
        title: Row(
          children: [
            const _BrandCore(),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _titles[_index],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BTC // ${_subtitles[_index]}',
                    style: mono(
                      size: 9.5,
                      weight: FontWeight.w700,
                      color: AppColors.cyan,
                      spacing: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.panelHigh.withOpacity(.72),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                kAppVersionBadge,
                style: mono(
                  size: 9.5,
                  weight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= PlatformProfile.wideBreakpoint;

          // Sur un grand ecran, une colonne de cartes etiree sur 1900 pixels
          // est illisible : on la borne et on la centre.
          final pages = IndexedStack(
            index: _index,
            children: const [
              DashboardScreen(),
              LabScreen(),
              HistoryScreen(),
              ConverterScreen(),
              ConfigScreen(),
              TutorialScreen(),
            ],
          );

          final content = wide
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: pages,
                  ),
                )
              : pages;

          return Stack(
            children: [
              const FuturisticBackground(),
              SafeArea(
                top: false,
                child: wide
                    ? Row(
                        children: [
                          _ReactorRail(
                            index: _index,
                            onSelected: (i) => setState(() => _index = i),
                          ),
                          Expanded(child: content),
                        ],
                      )
                    : content,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >=
              PlatformProfile.wideBreakpoint
          ? null
          : _ReactorNavigation(
              index: _index,
              onSelected: (i) => setState(() => _index = i),
            ),
    );
  }
}

/// Navigation laterale, affichee des que la fenetre est assez large.
class _ReactorRail extends StatelessWidget {
  const _ReactorRail({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.bolt_outlined, active: Icons.bolt_rounded, label: 'Minage'),
    (icon: Icons.science_outlined, active: Icons.science_rounded, label: 'Labo'),
    (icon: Icons.history_outlined, active: Icons.history_rounded, label: 'Sessions'),
    (icon: Icons.euro_outlined, active: Icons.euro_rounded, label: 'Euros'),
    (icon: Icons.tune_outlined, active: Icons.tune_rounded, label: 'Reglages'),
    (icon: Icons.school_outlined, active: Icons.school_rounded, label: 'Guide'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      margin: const EdgeInsets.fromLTRB(14, 8, 4, 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.panel.withOpacity(.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: index == i
                        ? AppColors.amber.withOpacity(.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: index == i ? AppColors.amber.withOpacity(.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        index == i ? _items[i].active : _items[i].icon,
                        size: 19,
                        color:
                            index == i ? AppColors.amber : AppColors.muted,
                      ),
                      const SizedBox(width: 11),
                      Text(
                        _items[i].label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              index == i ? FontWeight.w700 : FontWeight.w600,
                          color: index == i ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'F5 demarre\nF11 plein ecran\nCtrl+1..6 onglets',
              style: mono(size: 9.5, color: AppColors.dim),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandCore extends StatelessWidget {
  const _BrandCore();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.amberHot, AppColors.amber, Color(0xFFB95800)],
        ),
        border: Border.all(color: const Color(0xFFFFCB7B).withOpacity(.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withOpacity(.34),
            blurRadius: 18,
            spreadRadius: -2,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withOpacity(.22), width: 1.4),
            ),
          ),
          const Text(
            'B',
            style: TextStyle(
              color: Color(0xFF171008),
              fontWeight: FontWeight.w900,
              fontSize: 21,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactorNavigation extends StatelessWidget {
  const _ReactorNavigation({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.abyss,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF172135), Color(0xFF0A0F1B)],
          ),
          border: Border.all(color: AppColors.lineBright.withOpacity(.72)),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(.07),
              blurRadius: 22,
              spreadRadius: -4,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.amber.withOpacity(.16),
              iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                    size: 22,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.amberHot
                        : AppColors.muted,
                  )),
              labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                    fontSize: 10.5,
                    letterSpacing: .2,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.ink
                        : AppColors.muted,
                  )),
            ),
            child: NavigationBar(
              height: 68,
              selectedIndex: index,
              onDestinationSelected: onSelected,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.bolt_rounded), label: 'Minage'),
                NavigationDestination(icon: Icon(Icons.science_rounded), label: 'Labo'),
                NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Sessions'),
                NavigationDestination(icon: Icon(Icons.currency_bitcoin_rounded), label: 'Euros'),
                NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Reglages'),
                NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Guide'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
