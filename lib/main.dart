import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CarevoraApp()));
}

class CarevoraApp extends StatefulWidget {
  const CarevoraApp({super.key});

  @override
  State<CarevoraApp> createState() => _CarevoraAppState();
}

class _CarevoraAppState extends State<CarevoraApp> {
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
    return MaterialApp.router(
      key: _routerKey,
      title: 'Carevora – Compassionate Care, Smarter Tomorrow',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
    );
  }
}
