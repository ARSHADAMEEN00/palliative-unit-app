import 'package:flutter/material.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:provider/provider.dart';

class FeaturePermissionMiddleware {
  FeaturePermissionMiddleware._();

  static bool can(
    BuildContext context,
    String featureId, {
    bool listen = false,
  }) {
    final auth = Provider.of<AuthService>(context, listen: listen);
    return auth.hasFeature(featureId);
  }

  static bool ensure(
    BuildContext context,
    String featureId, {
    String? moduleName,
  }) {
    if (can(context, featureId)) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${moduleName ?? AppFeature.label(featureId)} is not enabled for this unit.',
        ),
      ),
    );
    return false;
  }

  static Future<T?> push<T>(
    BuildContext context, {
    required String featureId,
    required Widget page,
    String? moduleName,
  }) {
    if (!ensure(context, featureId, moduleName: moduleName)) {
      return Future<T?>.value();
    }

    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (context) => page));
  }
}

class FeatureGate extends StatelessWidget {
  const FeatureGate({
    super.key,
    required this.featureId,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String featureId;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return context.watch<AuthService>().hasFeature(featureId)
        ? child
        : fallback;
  }
}
