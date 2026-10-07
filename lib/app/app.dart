import 'package:flutter/material.dart';
import 'package:yening_ecos/widgets/splash_page.dart';

import '../core/ui/app_theme.dart';

class MyApp extends StatefulWidget {
  const new({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yening Ecos',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
      // debugShowMaterialGrid: true,
    );
  }
}
