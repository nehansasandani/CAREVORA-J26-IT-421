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

  // In-memory cache for decoded base64 image bytes to avoid re-decoding
  // on every rebuild, which causes MemoryImage reference changes and image blinking.
  static final Map<String, Uint8List> _base64Cache = {};

  const CarevoraAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 20,
    this.initials,
    this.fallbackIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  static Uint8List? _decodeBase64(String rawUrl) {
    if (_base64Cache.containsKey(rawUrl)) {
      return _base64Cache[rawUrl];
    }
    try {
      String rawB64 = rawUrl;
      if (rawB64.contains(',')) {
        rawB64 = rawB64.substring(rawB64.indexOf(',') + 1);
      }
      final cleanBase64 = rawB64.replaceAll(RegExp(r'\s+'), '');
      if (cleanBase64.isNotEmpty) {
        final Uint8List bytes = base64Decode(cleanBase64);
        if (bytes.isNotEmpty) {
          if (_base64Cache.length >= 200) {
            _base64Cache.remove(_base64Cache.keys.first);
          }
          _base64Cache[rawUrl] = bytes;
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('CarevoraAvatar base64 decode error: $e');
    }
    return null;
  }

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
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildFallback(fg),
        );
      } else if (url.startsWith('assets/')) {
        imageContent = Image.asset(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildFallback(fg),
        );
      } else {
        // Base64 data URL (e.g. data:image/jpeg;base64,...) or raw Base64 string
        final bytes = _decodeBase64(url);
        if (bytes != null && bytes.isNotEmpty) {
          imageContent = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildFallback(fg),
          );
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
