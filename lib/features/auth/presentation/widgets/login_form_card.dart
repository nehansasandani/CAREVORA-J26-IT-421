import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import 'common/app_text_field.dart';
import 'common/gradient_button.dart';
import 'common/shake_widget.dart';
import 'forgot_password_sheet.dart';
import 'lockout_banner.dart';
import 'secure_footer.dart';
import 'sso_dialog.dart';

const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

class LoginFormCard extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToRegister;

  const LoginFormCard({
    super.key,
    this.onSwitchToRegister,
  });

  @override
  ConsumerState<LoginFormCard> createState() => _LoginFormCardState();
}

class _LoginFormCardState extends ConsumerState<LoginFormCard> {
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
  bool _isDemoChipDismissed = false;
  Timer? _passwordHideTimer;

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
    _checkCapsLock();
    return false;
  }

  void _checkCapsLock() {
    final isCaps = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
    if (mounted && _capsLockOn != isCaps) {
      setState(() => _capsLockOn = isCaps);
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });

    if (!_obscurePassword) {
      _passwordHideTimer?.cancel();
      _passwordHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_obscurePassword) {
          setState(() => _obscurePassword = true);
        }
      });
    }
  }

  void _fillDemoCredentials() {
    setState(() {
      _emailController.text = 'seetha@carevora.com';
      _passwordController.text = 'demo1234';
      _isDemoChipDismissed = true;
    });
  }

  void _fillDoctorCredentials() {
    setState(() {
      _emailController.text = 'doctor@carevora.com';
      _passwordController.text = 'doctor123';
      _isDemoChipDismissed = true;
    });
  }

  void _fillAdminCredentials() {
    setState(() {
      _emailController.text = 'admin@carevora.com';
      _passwordController.text = 'admin123';
      _isDemoChipDismissed = true;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _hasSubmittedOnce = true);
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider).login(
          _emailController.text.trim(),
          _passwordController.text,
          _rememberMe,
        );

    if (success && mounted) {
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
    } else if (mounted) {
      _shakeKey.currentState?.shake();
      _passwordController.clear();
    }
  }

  void _openForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ForgotPasswordSheet(),
    );
  }

  void _openSsoDialog() {
    showDialog(
      context: context,
      builder: (context) => const SsoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.watch(authProvider);
    final authState = authNotifier.state;

    return ShakeWidget(
      key: _shakeKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.lilac.withValues(alpha: 0.9),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
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
                // Top Secure Accent Line
                Center(
                  child: Container(
                    height: 3,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accentPink],
                      ),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Shield Emblem & Heading
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.shieldCheck,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
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
                const SizedBox(height: 20),

                // Demo Mode Access Chip
                if (kDemoMode && !_isDemoChipDismissed) ...[
                  _buildDemoChip(),
                  const SizedBox(height: 16),
                ],

                // Session Timeout / Info Banner
                if (authState.infoMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(height: 16),
                ],

                // Error Banner
                if (authState.errorMessage != null &&
                    !authState.isLockedOut) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.riskHighBg,
                      borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(height: 16),
                ],

                // Lockout Banner (if locked out)
                if (authState.isLockedOut) ...[
                  LockoutBanner(
                    secondsRemaining: authState.lockoutSecondsRemaining,
                    onForgotPassword: _openForgotPassword,
                  ),
                  const SizedBox(height: 20),
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
                const SizedBox(height: 16),

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
                const SizedBox(height: 14),

                // Remember Me & Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
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
                              'Keeps session active on this device. Do not use on shared computers.',
                          child: const Text(
                            'Remember me',
                            style: TextStyle(
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),

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
                const SizedBox(height: 18),

                // Sign in with SSO Button
                OutlinedButton(
                  onPressed: _openSsoDialog,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: AppColors.lilac.withValues(alpha: 0.8),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                            context.go('/register');
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
                const SizedBox(height: 28),

                // Bottom Secure Footer
                const SecureFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lilac),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.key_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Demo Presets (Quick Fill):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildDemoFillBtn('Doctor', AppColors.primary, _fillDoctorCredentials),
              _buildDemoFillBtn('Admin', AppColors.primaryDeep, _fillAdminCredentials),
              _buildDemoFillBtn('Caregiver', AppColors.navy, _fillDemoCredentials),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoFillBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '+ Fill $label',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
