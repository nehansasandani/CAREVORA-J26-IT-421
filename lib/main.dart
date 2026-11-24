import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/app_settings_controller.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CarevoraApp()));
}

class CarevoraApp extends ConsumerStatefulWidget {
  const CarevoraApp({super.key});

  @override
  ConsumerState<CarevoraApp> createState() => _CarevoraAppState();
}

class _CarevoraAppState extends ConsumerState<CarevoraApp> {
  // Hue-preserving soft midnight dark-mode matrix:
  // Inverts luminance into comfortable deep slate-indigo while preserving
  // Carevora brand hues (violet, teal, rose, blue, emerald) across every screen.
  static const List<double> _smartDarkModeMatrix = <double>[
    0.4936, -1.2298, -0.1238, 0, 238.4,
    -0.3664, -0.3698, -0.1238, 0, 241.0,
    -0.3664, -1.2298, 0.7362, 0, 251.2,
    0, 0, 0, 1, 0,
  ];

  Key _routerKey = UniqueKey();

  @override
  void reassemble() {
    super.reassemble();
    AppRouter.reload();
    setState(() {
      _routerKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final baseTheme = AppTheme.lightTheme;
    final effectiveTheme = settings.highContrastMode
        ? baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              onSurface: const Color(0xFF090D16),
              outline: const Color(0xFF334155),
            ),
            textTheme: baseTheme.textTheme.apply(
              bodyColor: const Color(0xFF090D16),
              displayColor: const Color(0xFF090D16),
            ),
          )
        : baseTheme;

    return MaterialApp.router(
      key: _routerKey,
      title: 'Carevora – Compassionate Care, Smarter Tomorrow',
      theme: effectiveTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        Widget content = MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
        if (settings.isDarkMode) {
          content = ColorFiltered(
            colorFilter: const ColorFilter.matrix(_smartDarkModeMatrix),
            child: content,
          );
        }
        if (settings.eyeComfortWarmTint) {
          content = Stack(
            children: [
              content,
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x16F59E0B)),
                ),
              ),
            ],
          );
        }
        return content;
      },
    );
  }
}
