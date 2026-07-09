import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ledgr/app/router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

/// Application root: wires dynamic color, Material 3 themes, localization, and
/// the router.
class LedgrApp extends StatefulWidget {
  const LedgrApp({super.key});

  @override
  State<LedgrApp> createState() => _LedgrAppState();
}

class _LedgrAppState extends State<LedgrApp> {
  final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppL10n.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightDynamic?.harmonized()),
          darkTheme: AppTheme.dark(darkDynamic?.harmonized()),
          themeMode: ThemeMode.system,
          routerConfig: _router,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
        );
      },
    );
  }
}
