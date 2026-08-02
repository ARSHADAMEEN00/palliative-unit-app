import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_theme.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:oruma_app/loginscreen.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/trial_ended_screen.dart';
import 'package:oruma_app/widgets/slide_page_route.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  await authService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarDividerColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: authService)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final pageTransitionsTheme = PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: _PalliativeAppPageTransitionsBuilder(),
      },
    );
    final lightTheme = AppTheme.light(
      pageTransitionsTheme: pageTransitionsTheme,
    );
    final darkTheme = AppTheme.dark(pageTransitionsTheme: pageTransitionsTheme);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Palliative App',
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!kIsWeb) return content;

        // Keep the app centered and readable on wide web screens.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              width: double.infinity,
              color: AppColors.background,
              child: content,
            ),
          ),
        );
      },
      theme: lightTheme,
      darkTheme: darkTheme,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isAccessBlocked) {
            return const TrialEndedScreen();
          }

          return auth.isAuthenticated
              ? const Homescreen()
              : const Loginscreen();
        },
      ),
    );
  }
}

/// Hooks Flutter's [PageTransitionsTheme] system so that every
/// [MaterialPageRoute] automatically uses the smooth slide transition
/// defined in [buildSlideTransition].
class _PalliativeAppPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildSlideTransition(context, animation, secondaryAnimation, child);
  }
}
