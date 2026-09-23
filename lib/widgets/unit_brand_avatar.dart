import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class UnitBrandAvatar extends StatelessWidget {
  const UnitBrandAvatar({
    super.key,
    this.size = 40,
    this.iconSize,
    this.preferAppIcon = false,
    this.backgroundColor = const Color(0xFFE6F1FB),
    this.iconColor = const Color(0xFF185FA5),
    this.fallbackIcon = Icons.local_hospital_outlined,
    this.assetFallback = 'assets/logo/logo.png',
    this.border,
  });

  final double size;
  final double? iconSize;
  final bool preferAppIcon;
  final Color backgroundColor;
  final Color iconColor;
  final IconData fallbackIcon;
  final String assetFallback;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final auth = _maybeAuth(context);
    final source = auth == null
        ? null
        : preferAppIcon
        ? auth.unitAppIcon ?? auth.unitLogo
        : auth.unitLogo ?? auth.unitAppIcon;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageFromSource(source) ?? _assetFallback(),
    );
  }

  Widget? _imageFromSource(String? source) {
    if (source == null) return null;
    if (source.startsWith('data:image/')) {
      final commaIndex = source.indexOf(',');
      if (commaIndex < 0) return null;
      try {
        return Image.memory(
          base64Decode(source.substring(commaIndex + 1)),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, _, _) => _fallbackIcon(),
        );
      } catch (_) {
        return null;
      }
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => _fallbackIcon(),
      );
    }

    return null;
  }

  Widget _assetFallback() {
    return Image.asset(
      assetFallback,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(fallbackIcon, color: iconColor, size: iconSize ?? size * 0.55);
  }

  AuthService? _maybeAuth(BuildContext context) {
    try {
      return context.watch<AuthService>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
