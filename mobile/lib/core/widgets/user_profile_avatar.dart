import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/tokens/colors.dart';

/// A premium, high-fidelity user profile avatar with elegant initials fallback
/// and image error handling. Supports brand-immersion gradients.
class UserProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? displayName;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;

  const UserProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.size = 40,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Extract initials or use 'U' fallback
    String getInitials() {
      final name = displayName?.trim() ?? '';
      if (name.isEmpty) return 'U';
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
      return 'U';
    }

    // Build the gorgeous fallback initials container
    Widget buildFallback() {
      final initials = getInitials();

      // Elegant gradient backgrounds using primary/accent colors for richness
      final gradient = LinearGradient(
        colors: [
          primaryColor,
          primaryColor.withValues(alpha: 0.65),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.4,
            letterSpacing: -0.5,
          ),
        ),
      );
    }

    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    Widget avatarWidget;
    if (hasUrl) {
      avatarWidget = CachedNetworkImage(
        imageUrl: avatarUrl!.trim(),
        imageBuilder: (context, imageProvider) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.08),
          ),
          child: Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => buildFallback(),
      );
    } else {
      avatarWidget = buildFallback();
    }

    if (borderWidth > 0) {
      return Container(
        width: size + borderWidth * 2 + 3,
        height: size + borderWidth * 2 + 3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? primaryColor.withValues(alpha: 0.25),
            width: borderWidth,
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
