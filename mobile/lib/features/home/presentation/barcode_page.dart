import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../settings/presentation/user_profile_cubit.dart';
import 'widgets/barcode_main_card.dart';
import 'widgets/barcode_profile_header.dart';
import 'widgets/quick_stats_dashboard.dart';
import 'widgets/scanner_mode_toggle.dart';

/// A premium, high-fidelity Barcode and QR Code loyalty page.
/// Integrates brand-immersion, custom vector paint code renderers,
/// scrolling neon scan line, rotating dynamic session tokens,
/// and high-contrast Cashier Scan Mode.
class BarcodePage extends StatefulWidget {
  const BarcodePage({super.key});

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage>
    with TickerProviderStateMixin {
  bool _isBarcodeMode = true; // Toggle between Barcode and QR Code
  bool _isScannerMode = false; // Boosts contrast/simulates max brightness
  late String _membershipId;
  late String _securityToken;

  // Countdown timer for rotating secure token
  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  static const int _maxSeconds = 60;

  // Animation Controllers
  late AnimationController _laserController;
  late AnimationController _flipController;
  late AnimationController _scannerModeController;

  @override
  void initState() {
    super.initState();
    _membershipId = 'LOOB-8839-9182-0012';
    _generateNewSecurityToken();

    // Laser scan line controller (looping up and down)
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 3D card flip controller (runs once on token rotate)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Scanner mode fade-in animation
    _scannerModeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _laserController.dispose();
    _flipController.dispose();
    _scannerModeController.dispose();
    super.dispose();
  }

  void _generateNewSecurityToken() {
    // Generates a mock dynamic 6-digit cashier validation suffix
    final random = math.Random();
    final code = 100000 + random.nextInt(900000);
    setState(() {
      _securityToken = '$code';
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = _maxSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _rotateSecurityToken();
      }
    });
  }

  void _rotateSecurityToken() {
    // 3D card flip animation sequence
    _flipController.forward(from: 0.0).then((_) {
      _generateNewSecurityToken();
      _flipController.reverse();
    });
    HapticFeedback.mediumImpact();
    _startTimer();
  }

  void _copyToClipboard() {
    final fullCode = '$_membershipId-$_securityToken';
    Clipboard.setData(ClipboardData(text: fullCode));
    HapticFeedback.lightImpact();

    // Premium micro-snackbar notification
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'Membership ID Copied!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xl,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.watch<ThemeCubit>().state;
    final isTealive = brand.brandId == 1;

    // Elegant brand styling tokens
    final primaryColor = isTealive
        ? const Color(0xFF4C1D40)
        : const Color(0xFF0A0A0A);
    final accentColor = isTealive
        ? const Color(0xFFF3C623)
        : const Color(0xFFFFFF5A); // Fixed double prefix from original
    final surfaceColor = isTealive
        ? const Color(0xFFFDF8FB)
        : const Color(0xFF171717);

    return BlocBuilder<UserProfileCubit, UserProfileState>(
      builder: (context, profileState) {
        final profile = profileState is UserProfileLoaded
            ? profileState.profile
            : null;
        return Scaffold(
          backgroundColor: primaryColor,
          body: Stack(
            children: [
              // ── Elegant Animated Background Bubbles ────────────────────────────────
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -100,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // ── Scrollable Body with Clean Safe Spacings ────────────────────────────
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    // Translucent Custom App Bar
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: CircleAvatar(
                          backgroundColor: Colors.white12,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      centerTitle: true,
                      title: Text(
                        'Loyalty Card',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.md),

                            // ── Profile Banner Info ───────────────────────────────────
                            BarcodeProfileHeader(
                              profile: profile,
                              accentColor: accentColor,
                              primaryColor: primaryColor,
                              isTealive: isTealive,
                            ),

                            const SizedBox(height: AppSpacing.xl),

                            // ── Elegant Quick Stats Dashboard Card ─────────────────────
                            QuickStatsDashboard(profile: profile),

                            const SizedBox(height: AppSpacing.xl),

                            // ── Barcode / QR Code Main Scannable Card ─────────────────
                            AnimatedBuilder(
                              animation: _flipController,
                              builder: (context, child) {
                                final angle = _flipController.value * math.pi;
                                return Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001) // perspective
                                    ..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: angle >= math.pi / 2
                                      ? const SizedBox.shrink() // Hide back face during flip transition
                                      : BarcodeMainCard(
                                          isBarcodeMode: _isBarcodeMode,
                                          isScannerMode: _isScannerMode,
                                          membershipId: _membershipId,
                                          securityToken: _securityToken,
                                          secondsRemaining: _secondsRemaining,
                                          maxSeconds: _maxSeconds,
                                          accentColor: accentColor,
                                          surfaceColor: surfaceColor,
                                          isTealive: isTealive,
                                          laserController: _laserController,
                                          onCopy: _copyToClipboard,
                                          onToggleMode: (val) {
                                            setState(
                                              () => _isBarcodeMode = val,
                                            );
                                            HapticFeedback.lightImpact();
                                          },
                                        ),
                                );
                              },
                            ),

                            const SizedBox(height: AppSpacing.xl),

                            // ── Scanner Contrast / Brightness Booster Mode ─────────────
                            ScannerModeToggle(
                              isScannerMode: _isScannerMode,
                              accentColor: accentColor,
                              onChanged: (val) {
                                setState(() {
                                  _isScannerMode = val;
                                });
                                if (val) {
                                  _scannerModeController.forward();
                                } else {
                                  _scannerModeController.reverse();
                                }
                              },
                            ),

                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
