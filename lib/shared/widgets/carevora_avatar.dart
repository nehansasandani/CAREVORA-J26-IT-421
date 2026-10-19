import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CarevoraAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final String? initials;
  final IconData? fallbackIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CarevoraAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 20,
    this.initials,
    this.fallbackIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primarySoft;
    final fg = foregroundColor ?? AppColors.primary;
    final size = radius * 2;

    Widget? imageContent;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        imageContent = Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(fg),
        );
      } else if (url.startsWith('assets/')) {
        imageContent = Image.asset(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(fg),
        );
      } else {
        // Base64 data URL (e.g. data:image/jpeg;base64,...) or raw Base64 string
        try {
          String rawB64 = url;
          if (rawB64.contains(',')) {
            rawB64 = rawB64.substring(rawB64.indexOf(',') + 1);
          }
          final cleanBase64 = rawB64.replaceAll(RegExp(r'\s+'), '');
          if (cleanBase64.isNotEmpty) {
            final Uint8List bytes = base64Decode(cleanBase64);
            if (bytes.isNotEmpty) {
              imageContent = Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(fg),
              );
            }
          }
        } catch (e) {
          debugPrint('CarevoraAvatar base64 decode error: $e');
          imageContent = null;
        }
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: imageContent ?? _buildFallback(fg),
      ),
    );
  }

  Widget _buildFallback(Color fg) {
    if (initials != null && initials!.trim().isNotEmpty) {
      final text = initials!.trim().toUpperCase();
      final display = text.length > 2 ? text.substring(0, 2) : text;
      return Center(
        child: Text(
          display,
          style: TextStyle(
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        fallbackIcon ?? Icons.person,
        size: radius * 1.1,
        color: fg,
      ),
    );
  }
}
