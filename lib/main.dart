import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database/database_helper.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Light status-bar icons over the black app, and a black system nav bar.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await NotificationService.initialize();

  final onboardingDone =
      await DatabaseHelper.getSetting('onboarding_done') == 'true';

  runApp(PennyTrackApp(showOnboarding: !onboardingDone));
}

class PennyTrackApp extends StatelessWidget {
  const PennyTrackApp({
    super.key,
    this.showOnboarding = false,
  });

  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PennyTrack',
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: showOnboarding ? const OnboardingScreen() : const AppShell(),
    );
  }
}
