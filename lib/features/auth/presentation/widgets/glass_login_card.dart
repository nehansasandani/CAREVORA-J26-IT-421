import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import 'common/app_text_field.dart';
import 'common/glass_container.dart';
import 'common/gradient_button.dart';
import 'common/rotating_message.dart';
import 'common/shake_widget.dart';
import 'forgot_password_sheet.dart';
import 'lockout_banner.dart';
import 'protected_signin_strip.dart';
import 'register_dialog.dart';
import 'secure_footer.dart';
import 'sso_dialog.dart';

const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

class GlassLoginCard extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToRegister;

  const GlassLoginCard({
    super.key,
    this.onSwitchToRegister,
  });

  @override
  ConsumerState<GlassLoginCard> createState() => _GlassLoginCardState();
}

class _GlassLoginCardState extends ConsumerState<GlassLoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _capsLockOn = false;
  bool _hasSubmittedOnce = false;
  bool _showSuccessCheck = false;
  final bool _isDemoChipDismissed = false;
  Timer? _passwordHideTimer;

  static const List<String> _careReassurances = [
    'Every resident matters.',
    'Early signs, caught early.',
    'Supporting caregivers, every day.',
  ];

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(_checkCapsLock);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _passwordHideTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.removeListener(_checkCapsLock);
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isCapsLock = HardwareKeyboard.instance.lockModesEnabled.contains(
      KeyboardLockMode.capsLock,
    );
    if (isCapsLock != _capsLockOn) {
      if (mounted) setState(() => _capsLockOn = isCapsLock);
    }
    return false;
  }

  void _checkCapsLock() {
    if (_passwordFocusNode.hasFocus) {
      final isCapsLock = HardwareKeyboard.instance.lockModesEnabled.contains(
        KeyboardLockMode.capsLock,
      );
      if (isCapsLock != _capsLockOn && mounted) {
        setState(() => _capsLockOn = isCapsLock);
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });

    _passwordHideTimer?.cancel();
    // Security Feature: Password auto re-hides 3 seconds after being revealed
    if (!_obscurePassword) {
      _passwordHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _obscurePassword = true);
        }
      });
    }
  }

  void _fillCaregiverDavid() {
    setState(() {
      _emailController.text = 'david.silva@carevora.com';
      _passwordController.text = 'carevora123';
    });
  }

  void _fillCaregiverEleanor() {
    setState(() {
      _emailController.text = 'eleanor.vance@carevora.com';
      _passwordController.text = 'carevora_admin';
    });
  }

  void _fillDoctor() {
    setState(() {
      _emailController.text = 'dr.reed@carevora.com';
      _passwordController.text = 'doctor123';
    });
  }

  void _fillElder() {
    setState(() {
      _emailController.text = 'sarah.jenkins@carevora.com';
      _passwordController.text = 'carevora123';
    });
  }


  Future<void> _handleSubmit() async {
    setState(() => _hasSubmittedOnce = true);

    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    final success = await ref.read(authProvider).login(
          _emailController.text.trim(),
          _passwordController.text,
          _rememberMe,
        );

    if (!mounted) return;

    if (success) {
      setState(() => _showSuccessCheck = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        final authState = ref.read(authProvider).state;
        if (authState.isAdmin) {
          context.go('/admin/dashboard');
        } else if (authState.isElder) {
          context.go('/dashboard');
        } else {
          context.go('/dashboard/residents');
        }
      }
    } else {
      // Clear password after failed attempt & subtle shake
      _passwordController.clear();
      _shakeKey.currentState?.shake();
    }
  }

  void _openForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ForgotPasswordSheet(),
    );
  }

  void _openSsoDialog() {
    showDialog(
      context: context,
      builder: (_) => const SsoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.watch(authProvider);
    final authState = authNotifier.state;

    return ShakeWidget(
      key: _shakeKey,
      child: GlassContainer(
        borderRadius: 32,
        blur: 20,
        color: AppColors.glassWhite,
        borderColor: AppColors.glassBorder,
        borderWidth: 1.5,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: _hasSubmittedOnce
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Gradient Accent Line (primary -> accentPink)
                Center(
                  child: Container(
                    height: 3.5,
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accentPink],
                      ),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Shield Tile & Heading
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.lilac.withValues(alpha: 0.8),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.shieldCheck,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.body,
                              ),
                              children: [
                                TextSpan(text: 'Sign in to continue to '),
                                TextSpan(
                                  text: 'Carevora',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Rotating Care Reassurance Subtitle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.heartHandshake,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RotatingMessage(
                          messages: _careReassurances,
                          interval: const Duration(seconds: 5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Demo Mode Access Chip
                if (kDemoMode && !_isDemoChipDismissed) ...[
                  _buildDemoChip(),
                  const SizedBox(height: 14),
                ],

                // Session Timeout / Info Banner
                if (authState.infoMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.infoMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Error Banner
                if (authState.errorMessage != null &&
                    !authState.isLockedOut) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.riskHighBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.riskHigh.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppColors.riskHigh,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.riskHigh,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Lockout Banner
                if (authState.isLockedOut) ...[
                  LockoutBanner(
                    secondsRemaining: authState.lockoutSecondsRemaining,
                    onForgotPassword: _openForgotPassword,
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Input
                AppTextField(
                  controller: _emailController,
                  label: 'Care Home Email',
                  hintText: 'nurse@carevora.com',
                  leadingIcon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email.';
                    }
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password Input
                AppTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  label: 'Password',
                  leadingIcon: LucideIcons.lock,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSubmit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password.';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                  trailing: Semantics(
                    label: _obscurePassword ? 'Show password' : 'Hide password',
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      onPressed: _togglePasswordVisibility,
                    ),
                  ),
                ),

                // Caps Lock Warning
                if (_capsLockOn) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: AppColors.riskModerate,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Caps Lock is ON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.riskModerate,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Remember Me & Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setState(() => _rememberMe = val ?? true);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              'Keeps you signed in on this device. Do not use on shared computers.',
                          child: const Text(
                            'Remember me',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.body,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _openForgotPassword,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Primary Login Button
                GradientButton(
                  isLoading: authState.isLoading,
                  loadingLabel: 'Signing In...',
                  onPressed: authState.isLockedOut ? null : _handleSubmit,
                  child: _showSuccessCheck
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Welcome back!',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              LucideIcons.logIn,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'LOGIN',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),

                // Protected Sign-In Strip (Security / Trust Cues)
                const ProtectedSignInStrip(),
                const SizedBox(height: 18),

                // "or" Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.border,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'or',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.border,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sign in with SSO Button
                OutlinedButton(
                  onPressed: _openSsoDialog,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.white.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: AppColors.lilac.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        LucideIcons.shield,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Sign in with SSO',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Register Link
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.body,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (widget.onSwitchToRegister != null) {
                            widget.onSwitchToRegister!();
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => const RegisterDialog(),
                            );
                          }
                        },
                        child: const Text(
                          'Register here',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Bottom Secure Disclaimer & Footer
                const SecureFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _fillAdminCredentials() {
    setState(() {
      _emailController.text = 'admin@carevora.com';
      _passwordController.text = 'admin123';
    });
  }

  Widget _buildDemoChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lilac),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.key_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Quick Role Presets (Click to autofill):',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetPill(
                label: 'Caregiver (David - Golden Sunset)',
                color: AppColors.primary,
                onTap: _fillCaregiverDavid,
              ),
              _buildPresetPill(
                label: 'Doctor (Dr. Reed - All Homes)',
                color: const Color(0xFF0D9488),
                onTap: _fillDoctor,
              ),
              _buildPresetPill(
                label: 'Elder (Sarah Jenkins - Serene Valley)',
                color: const Color(0xFFD97706),
                onTap: _fillElder,
              ),
              _buildPresetPill(
                label: 'Caregiver (Eleanor - Serene Valley)',
                color: const Color(0xFF4F46E5),
                onTap: _fillCaregiverEleanor,
              ),
              _buildPresetPill(
                label: 'Admin',
                color: AppColors.navy,
                onTap: _fillAdminCredentials,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetPill({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
