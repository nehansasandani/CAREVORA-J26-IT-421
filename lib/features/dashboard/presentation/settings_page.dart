import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/services/app_settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../auth/application/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Real resident details fetched from backend (nullable for Hot-Reload safety)
  String? _realRoomNumber;
  int? _realAge;
  String? _realFacilityName;
  String? _realAvatarUrl;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchRealResidentProfile();
  }

  Future<void> _fetchRealResidentProfile() async {
    final auth = ref.read(authProvider).state;
    if (!auth.isElder || auth.token == null || auth.token!.isEmpty) {
      if (mounted) setState(() => _profileLoaded = true);
      return;
    }

    try {
      final res = await http
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/api/residents'),
            headers: {'Authorization': 'Bearer ${auth.token}'},
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'] as List?;
        if (list != null) {
          final myName = (auth.userName ?? '').trim().toLowerCase();
          final myFirst = myName.split(' ').first;
          Map<String, dynamic>? match;
          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;
            final rId = (item['id'] as num?)?.toInt();
            final rName = (item['name']?.toString() ?? '').trim().toLowerCase();
            if ((auth.residentId != null && rId == auth.residentId) ||
                (myName.isNotEmpty && rName == myName) ||
                (myFirst.isNotEmpty && rName.startsWith(myFirst))) {
              match = item;
              break;
            }
          }
          if (match != null && mounted) {
            setState(() {
              _realRoomNumber = match!['roomNumber']?.toString().trim();
              _realAge = (match['age'] as num?)?.toInt();
              _realFacilityName = match['elderHomeName']?.toString().trim();
              final av = match['avatarUrl']?.toString().trim();
              if (av != null && av.isNotEmpty) _realAvatarUrl = av;
              _profileLoaded = true;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _profileLoaded = true);
  }

  void _showSavedToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        margin: const EdgeInsets.all(18),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmLogout(bool isSi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isSi ? 'ගිණුමෙන් ඉවත් වන්නද?' : 'Log Out of Carevora?',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          isSi
              ? 'ඔබට නැවත පිවිසීමට ඔබේ විද්‍යුත් තැපෑල සහ මුරපදය භාවිතා කළ හැකිය.'
              : 'You can sign back in anytime using your email and password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isSi ? 'නැත' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isSi ? 'ඉවත් වන්න' : 'Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final lang = ref.watch(languageProvider);
    final isSi = lang.isSinhala;
    final settings = ref.watch(appSettingsProvider);
    final isElder = authState.isElder;

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: SizedBox.shrink(),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Attractive Gradient Header Banner
                  _buildSettingsHeader(isSi, isElder),
                  const SizedBox(height: 18),

                  // 2. Real User / Resident Profile Card (Zero Dummy Data!)
                  _buildRealProfileCard(authState, isSi, isElder),
                  const SizedBox(height: 20),

                  // 3. Language Preference (Live sync with languageProvider)
                  _buildSectionHeading(
                    icon: LucideIcons.languages,
                    color: const Color(0xFF2563EB),
                    title: isSi ? 'භාෂාව තෝරන්න' : 'App Language',
                    subtitle: isSi
                        ? 'මුළු යෙදුමේම භාෂාව සහ හඬ මඟපෙන්වීම වෙනස් කරන්න'
                        : 'Switch both screen labels and spoken voice guidance instantly',
                  ),
                  const SizedBox(height: 10),
                  _buildLanguageCard(lang, isSi),
                  const SizedBox(height: 22),

                  // 4. Live Display & Reading Comfort (Theme + Text Size + Warm Tint + Contrast)
                  _buildSectionHeading(
                    icon: LucideIcons.eye,
                    color: const Color(0xFF7C3AED),
                    title: isSi
                        ? 'කියවීමේ පහසුව සහ තිර සැකසුම්'
                        : 'Display & Reading Comfort',
                    subtitle: isSi
                        ? 'මෙහි වෙනස්කම් සැනෙකින් මුළු යෙදුම පුරාම ක්‍රියාත්මක වේ'
                        : 'Changes apply live across every screen in Carevora',
                  ),
                  const SizedBox(height: 10),
                  _buildDisplayComfortCard(settings, isSi),
                  const SizedBox(height: 22),

                  // 5. Role-Specific Real Controls (Elder vs Staff)
                  if (isElder) ...[
                    _buildSectionHeading(
                      icon: LucideIcons.bell,
                      color: const Color(0xFFDB2777),
                      title: isSi
                          ? 'මිතුරු ආරාධනා සහ සහාය'
                          : 'Game Invites & Care Support',
                      subtitle: isSi
                          ? 'මිතුරන්ගේ ක්‍රීඩා ආරාධනා සහ හදිසි උපකාර සැකසුම්'
                          : 'Manage live friend invitations and quick care station help',
                    ),
                    const SizedBox(height: 10),
                    _buildElderNotificationsCard(authState, settings, isSi),
                  ] else ...[
                    _buildSectionHeading(
                      icon: LucideIcons.stethoscope,
                      color: const Color(0xFF0284C7),
                      title: isSi ? 'සායනික මනාපයන්' : 'Clinical Workflow Preferences',
                      subtitle: isSi
                          ? 'අවදානම් දැනුම්දීම් සහ වාර්තා ආකෘතිය'
                          : 'High-risk alert preferences and default report export format',
                    ),
                    const SizedBox(height: 10),
                    _buildStaffClinicalCard(settings, isSi),
                  ],

                  const SizedBox(height: 24),

                  // 6. Footer: Reset Defaults + Log Out
                  _buildFooterActions(settings, isSi),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsHeader(bool isSi, bool isElder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF312E81),
            Color(0xFF6D28D9),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isElder ? LucideIcons.heartHandshake : LucideIcons.slidersHorizontal,
              color: const Color(0xFF6D28D9),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isElder
                      ? (isSi
                          ? 'පෞද්ගලික පහසුකම් සහ සැකසුම්'
                          : 'Personal Comfort & Settings')
                      : (isSi ? 'සත්කාරක සැකසුම්' : 'Care Specialist Settings'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isSi
                      ? 'අකුරු ප්‍රමාණය, භාෂාව සහ තිරයේ පහසුකම් ඔබට කැමති ලෙස සකසා ගන්න.'
                      : 'Personalize text size, language, and display comfort.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  size: 15,
                  color: Color(0xFFA7F3D0),
                ),
                const SizedBox(width: 6),
                Text(
                  isSi ? 'ස්වයංක්‍රීයව සුරැකේ' : 'Auto-Saved',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealProfileCard(AuthState auth, bool isSi, bool isElder) {
    final rawName =
        (auth.userName ?? '').trim().isNotEmpty
            ? auth.userName!.trim()
            : (isElder ? 'Senior Resident' : 'Care Specialist');
    final displayName = isSi
        ? SinhalaNameTransliterator.toSinhala(rawName, fallback: rawName)
        : rawName;
    final facility = (_realFacilityName != null && _realFacilityName!.isNotEmpty)
        ? _realFacilityName!
        : (auth.elderHomeName ?? '').trim();
    final email = (auth.email ?? '').trim();
    final avatarUrl = _realAvatarUrl ?? auth.avatarUrl;

    String roleLabel() {
      if (auth.isElder) return isSi ? 'ජ්‍යෙෂ්ඨ සාමාජික' : 'SENIOR RESIDENT';
      if (auth.isDoctor) return isSi ? 'වෛද්‍යවරයා' : 'DOCTOR';
      if (auth.isAdmin) return isSi ? 'පරිපාලක' : 'ADMIN';
      return isSi ? 'සත්කාරක නිලධාරී' : 'STAFF CAREGIVER';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFAF5FF), Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDDD6FE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF0D9488)],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CarevoraAvatar(
                    avatarUrl: avatarUrl,
                    radius: 30,
                    initials: rawName
                        .split(RegExp(r'\s+'))
                        .where((p) => p.isNotEmpty)
                        .take(2)
                        .map((p) => p[0])
                        .join()
                        .toUpperCase(),
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E1B4B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isElder
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleLabel(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: isElder
                                ? const Color(0xFF6D28D9)
                                : const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (facility.isNotEmpty)
                        _buildInfoChip(
                          Icons.home_work_rounded,
                          facility,
                          const Color(0xFF0F766E),
                          const Color(0xFFECFDF5),
                        ),
                      if (_realRoomNumber != null &&
                          _realRoomNumber!.isNotEmpty)
                        _buildInfoChip(
                          Icons.door_front_door_rounded,
                          isSi ? 'කාමරය $_realRoomNumber' : 'Room $_realRoomNumber',
                          const Color(0xFF4338CA),
                          const Color(0xFFEEF2FF),
                        ),
                      if (_realAge != null)
                        _buildInfoChip(
                          Icons.cake_rounded,
                          isSi ? 'වයස $_realAge' : 'Age $_realAge',
                          const Color(0xFF9D174D),
                          const Color(0xFFFDF2F8),
                        ),
                      if (email.isNotEmpty)
                        _buildInfoChip(
                          Icons.mail_outline_rounded,
                          email,
                          const Color(0xFF475569),
                          const Color(0xFFF1F5F9),
                        ),
                      if (!_profileLoaded && isElder)
                        _buildInfoChip(
                          Icons.sync_rounded,
                          isSi ? 'විස්තර ලබාගනිමින්...' : 'Loading details...',
                          const Color(0xFF64748B),
                          const Color(0xFFF8FAFC),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (isElder)
            Material(
              color: const Color(0xFFFFF1F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.4),
              ),
              child: InkWell(
                onTap: () => context.go('/dashboard/station-help'),
                borderRadius: BorderRadius.circular(13),
                hoverColor: const Color(0xFFFFE4E6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        size: 18,
                        color: Color(0xFFBE123C),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isSi ? 'සහාය ඇමතුම්' : 'Station Help',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBE123C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text,
    Color fg,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLanguageCard(LanguageNotifier lang, bool isSi) {
    return _buildCardShell(
      child: Row(
        children: [
          Expanded(
            child: _buildChoiceTile(
              selected: !isSi,
              accent: const Color(0xFF2563EB),
              title: '🇬🇧  English',
              subtitle: 'English interface & clear voice',
              onTap: () {
                lang.setLanguage(AppLanguage.english);
                _showSavedToast('Language switched to English');
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _buildChoiceTile(
              selected: isSi,
              accent: const Color(0xFF0D9488),
              title: '🇱🇰  සිංහල',
              subtitle: 'සිංහල අතුරුමුහුණත සහ සිංහල හඬ',
              onTap: () {
                lang.setLanguage(AppLanguage.sinhala);
                _showSavedToast('භාෂාව සිංහල වෙත මාරු කළා');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayComfortCard(AppSettingsController settings, bool isSi) {
    final scale = settings.textScaleFactor;
    final isNormal = scale < 1.06;
    final isLarge = scale >= 1.06 && scale < 1.17;
    final isXL = scale >= 1.17;

    return _buildCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSi ? 'තිර තේමාව (Light / Dark Theme)' : 'App Theme (Light / Dark)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildChoiceTile(
                  selected: !settings.isDarkMode,
                  accent: const Color(0xFFD97706),
                  title: isSi ? '☀️  දිවා තේමාව (Light)' : '☀️  Light Theme',
                  subtitle: isSi
                      ? 'දීප්තිමත් හා පැහැදිලි දිවා පෙනුම'
                      : 'Bright, clean & gentle daylight look',
                  onTap: () {
                    settings.setDarkMode(false);
                    _showSavedToast(
                      isSi
                          ? 'දිවා තේමාව (Light Theme) ක්‍රියාත්මක කළා'
                          : 'Switched to Light Theme',
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildChoiceTile(
                  selected: settings.isDarkMode,
                  accent: const Color(0xFF4F46E5),
                  title: isSi ? '🌙  රාත්‍රී තේමාව (Dark)' : '🌙  Dark Theme',
                  subtitle: isSi
                      ? 'රාත්‍රී කාලයේ ඇස්වලට සුවපහසු අඳුරු පෙනුම'
                      : 'Calm night look for low-light eye comfort',
                  onTap: () {
                    settings.setDarkMode(true);
                    _showSavedToast(
                      isSi
                          ? 'රාත්‍රී තේමාව (Dark Theme) ක්‍රියාත්මක කළා'
                          : 'Switched to Dark Theme',
                    );
                  },
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Text(
            isSi ? 'අකුරු ප්‍රමාණය (Live Text Size)' : 'Text Size (Applies Live)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  selected: isNormal,
                  accent: const Color(0xFF7C3AED),
                  label: isSi ? 'A  සාමාන්‍ය' : 'A  Normal',
                  onTap: () => settings.setTextScaleFactor(1.0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSegmentButton(
                  selected: isLarge,
                  accent: const Color(0xFF7C3AED),
                  label: isSi ? 'A+  ලොකු' : 'A+  Large',
                  onTap: () => settings.setTextScaleFactor(1.12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSegmentButton(
                  selected: isXL,
                  accent: const Color(0xFF7C3AED),
                  label: isSi ? 'A++  ඉතා ලොකු' : 'A++  Extra Large',
                  onTap: () => settings.setTextScaleFactor(1.22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Live Preview Box so elders immediately feel the new text size
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 17,
                  color: Color(0xFF6D28D9),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSi
                        ? 'පෙරදසුන: මෙම අකුරු ප්‍රමාණය ඔබට කියවීමට පහසුද?'
                        : 'Live Preview: Is this text size comfortable to read?',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF312E81),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildSwitchRow(
            icon: LucideIcons.sunMedium,
            accent: const Color(0xFFD97706),
            title: isSi
                ? 'ඇස් සඳහා උණුසුම් ආලෝක පෙරහන'
                : 'Warm Eye-Comfort Tint',
            subtitle: isSi
                ? 'තිරයේ දීප්තිය අඩු කර ඇස්වලට සුවපහසු උණුසුම් පැහැයක් දෙයි'
                : 'Adds a gentle warm amber tint to reduce eye strain',
            value: settings.eyeComfortWarmTint,
            onChanged: settings.setEyeComfortWarmTint,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildSwitchRow(
            icon: LucideIcons.contrast,
            accent: const Color(0xFF1E293B),
            title: isSi ? 'ඉහළ පැහැදිලි බව (High Contrast)' : 'High Contrast Reading',
            subtitle: isSi
                ? 'අකුරු තද කළු පැහැයෙන් වඩාත් පැහැදිලිව පෙන්වයි'
                : 'Makes letters darker and sharper across the app',
            value: settings.highContrastMode,
            onChanged: settings.setHighContrastMode,
          ),
        ],
      ),
    );
  }

  Widget _buildElderNotificationsCard(
    AuthState auth,
    AppSettingsController settings,
    bool isSi,
  ) {
    final facility = (_realFacilityName != null && _realFacilityName!.isNotEmpty)
        ? _realFacilityName!
        : (auth.elderHomeName ?? '').trim();

    return _buildCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSwitchRow(
            icon: LucideIcons.users,
            accent: const Color(0xFFDB2777),
            title: isSi
                ? 'මිතුරු ක්‍රීඩා ආරාධනා පණිවිඩ'
                : 'Friend Game Invite Popups',
            subtitle: isSi
                ? 'මිතුරෙකු විනෝද චාරිකා ක්‍රීඩාවට ආරාධනා කළ විට තිරයේ පෙන්වයි'
                : 'Show live popup cards when a friend invites you to play Shared Picnic',
            value: settings.gameInvitePopupsEnabled,
            onChanged: settings.setGameInvitePopupsEnabled,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildActionLinkRow(
            icon: Icons.support_agent_rounded,
            accent: const Color(0xFFE11D48),
            title: isSi
                ? 'සත්කාර මධ්‍යස්ථාන සහාය සහ ඇමතුම්'
                : 'Care Station Help & Caregiver Calls',
            subtitle: facility.isNotEmpty
                ? (isSi
                    ? '$facility හි සත්කාරක නිලධාරීන්ගෙන් ඕනෑම වේලාවක උපකාර ලබාගන්න'
                    : 'Reach caregivers or nurses at $facility whenever you need help')
                : (isSi
                    ? 'සත්කාරක නිලධාරීන්ගෙන් හෝ හෙදියන්ගෙන් ඕනෑම වේලාවක උපකාර ලබාගන්න'
                    : 'Reach caregivers or nurses whenever you need assistance'),
            buttonLabel: isSi ? 'සහාය ගන්න' : 'Open Help',
            onTap: () => context.go('/dashboard/station-help'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLinkRow({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: accent.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: accent.withValues(alpha: 0.35),
              width: 1.3,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: accent.withValues(alpha: 0.16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    buttonLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffClinicalCard(AppSettingsController settings, bool isSi) {
    return _buildCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSwitchRow(
            icon: LucideIcons.alertTriangle,
            accent: const Color(0xFFDC2626),
            title: isSi
                ? 'ඉහළ අවදානම් දැනුම්දීම්'
                : 'High-Risk Resident Alerts',
            subtitle: isSi
                ? 'මතක හෝ මානසික අවදානම වැඩි වූ විට ප්‍රමුඛතාව දක්වයි'
                : 'Highlight urgent cognitive & emotional alerts in dashboard views',
            value: settings.clinicalHighRiskAlerts,
            onChanged: settings.setClinicalHighRiskAlerts,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Text(
            isSi ? 'වාර්තා බාගැනීමේ ආකෘතිය' : 'Default Report Export Format',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  selected: settings.clinicalExportFormat == 'pdf',
                  accent: const Color(0xFF0284C7),
                  label: '📄 PDF Clinical Report',
                  onTap: () => settings.setClinicalExportFormat('pdf'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSegmentButton(
                  selected: settings.clinicalExportFormat == 'csv',
                  accent: const Color(0xFF0284C7),
                  label: '📊 CSV Data Export',
                  onTap: () => settings.setClinicalExportFormat('csv'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(AppSettingsController settings, bool isSi) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Material(
          color: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
          ),
          child: InkWell(
            onTap: () async {
              await settings.resetToRecommendedDefaults();
              _showSavedToast(
                isSi
                    ? 'නිර්දේශිත පහසු සැකසුම් වෙත යළි පිහිටුවා ඇත!'
                    : 'Reset to recommended comfort settings!',
              );
            },
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.rotateCcw,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSi
                        ? 'මුල් සැකසුම් වෙත ගන්න'
                        : 'Reset to Recommended Defaults',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: const Color(0xFFFEF2F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.4),
          ),
          child: InkWell(
            onTap: () => _confirmLogout(isSi),
            borderRadius: BorderRadius.circular(13),
            hoverColor: const Color(0xFFFEE2E2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    size: 17,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isSi ? 'ගිණුමෙන් ඉවත් වන්න' : 'Log Out',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceTile({
    required bool selected,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.09) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: selected ? accent : const Color(0xFFE2E8F0),
          width: selected ? 2.0 : 1.3,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: selected ? accent : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? accent : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required bool selected,
    required Color accent,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? accent : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? accent : const Color(0xFFCBD5E1),
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: accent,
        ),
      ],
    );
  }
}

/// Gentle, soothing ambient floating animation framing the outer margins
/// of the Settings page. Uses its own StatefulWidget & RepaintBoundary so it
/// is 100% Hot-Reload safe and keeps scrolling silky at 60fps.
class _SettingsAmbientBackdrop extends StatefulWidget {
  const _SettingsAmbientBackdrop();

  @override
  State<_SettingsAmbientBackdrop> createState() =>
      _SettingsAmbientBackdropState();
}

class _SettingsAmbientBackdropState extends State<_SettingsAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SettingsAmbientPainter(progress: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SettingsAmbientPainter extends CustomPainter {
  final double progress;

  const _SettingsAmbientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // 1. Soft breathing pastel aurora orbs around the outer perimeter
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.04 + math.sin(t) * 18,
        size.height * 0.14 + math.cos(t * 0.8) * 20,
      ),
      115,
      const Color(0xFF8B5CF6).withValues(alpha: 0.14),
    );
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.96 + math.cos(t) * 18,
        size.height * 0.22 + math.sin(t * 0.9) * 24,
      ),
      125,
      const Color(0xFF14B8A6).withValues(alpha: 0.14),
    );
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.05 + math.cos(t * 1.1) * 16,
        size.height * 0.72 + math.sin(t) * 22,
      ),
      120,
      const Color(0xFF38BDF8).withValues(alpha: 0.13),
    );
    _drawGlowOrb(
      canvas,
      Offset(
        size.width * 0.95 + math.sin(t * 0.9) * 16,
        size.height * 0.78 + math.cos(t * 1.1) * 20,
      ),
      118,
      const Color(0xFFF472B6).withValues(alpha: 0.13),
    );

    // 2. Delicate flowing translucent ribbons hugging the left & right edges
    _drawEdgeRibbon(
      canvas,
      size,
      isLeft: true,
      phase: t,
      color: const Color(0xFF7C3AED).withValues(alpha: 0.085),
    );
    _drawEdgeRibbon(
      canvas,
      size,
      isLeft: false,
      phase: -t + 1.4,
      color: const Color(0xFF0D9488).withValues(alpha: 0.085),
    );

    // 3. Concentric drifting pastel rings along both side margins
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.045 + math.sin(t + 0.5) * 9,
        size.height * 0.34 + math.cos(t) * 16,
      ),
      26,
      const Color(0xFF7C3AED).withValues(alpha: 0.22),
      innerRing: true,
    );
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.955 + math.cos(t + 1.1) * 9,
        size.height * 0.46 + math.sin(t * 1.2) * 18,
      ),
      30,
      const Color(0xFF0D9488).withValues(alpha: 0.22),
      innerRing: true,
    );
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.065 + math.cos(t * 1.3) * 8,
        size.height * 0.86 + math.sin(t) * 12,
      ),
      20,
      const Color(0xFFEC4899).withValues(alpha: 0.22),
    );
    _drawFloatingRing(
      canvas,
      Offset(
        size.width * 0.94 + math.sin(t * 1.2) * 8,
        size.height * 0.10 + math.cos(t * 1.1) * 12,
      ),
      18,
      const Color(0xFF3B82F6).withValues(alpha: 0.22),
    );

    // 4. Gently rotating soft rounded hexagons on outer borders
    _drawFloatingHexagon(
      canvas,
      Offset(
        size.width * 0.032 + math.cos(t) * 7,
        size.height * 0.56 + math.sin(t * 1.1) * 14,
      ),
      15,
      t * 0.5,
      const Color(0xFF6366F1).withValues(alpha: 0.24),
    );
    _drawFloatingHexagon(
      canvas,
      Offset(
        size.width * 0.965 + math.sin(t * 0.9) * 7,
        size.height * 0.66 + math.cos(t) * 14,
      ),
      16,
      -t * 0.45,
      const Color(0xFF14B8A6).withValues(alpha: 0.24),
    );

    // 5. Twinkling 4-point sparkles along left, right, top corners
    final sparkles = <(double, double, double, Color, double)>[
      (0.03, 0.22, 8.5, const Color(0xFF8B5CF6), 0.0),
      (0.075, 0.44, 6.5, const Color(0xFF0EA5E9), 1.3),
      (0.04, 0.68, 7.5, const Color(0xFFEC4899), 2.5),
      (0.08, 0.92, 6.0, const Color(0xFF14B8A6), 3.7),
      (0.965, 0.16, 8.0, const Color(0xFF14B8A6), 0.8),
      (0.925, 0.34, 6.5, const Color(0xFF8B5CF6), 2.1),
      (0.96, 0.58, 8.5, const Color(0xFF3B82F6), 3.3),
      (0.93, 0.84, 7.0, const Color(0xFFF43F5E), 4.6),
    ];

    for (final s in sparkles) {
      final pulse = 0.55 + 0.45 * math.sin(t * 2 + s.$5);
      final cx = size.width * s.$1 + math.sin(t + s.$5) * 6;
      final cy = size.height * s.$2 + math.cos(t + s.$5) * 9;
      _drawSparkle(
        canvas,
        Offset(cx, cy),
        s.$3 * (0.78 + 0.28 * pulse),
        s.$4.withValues(alpha: 0.20 + 0.32 * pulse),
      );
    }

    // 6. Soft drifting pastel wellness dots around the outer frame
    final dots = <(double, double, double, Color, double)>[
      (0.055, 0.12, 4.5, const Color(0xFF6366F1), 0.4),
      (0.025, 0.48, 3.8, const Color(0xFF14B8A6), 1.9),
      (0.068, 0.77, 4.2, const Color(0xFFF59E0B), 3.1),
      (0.945, 0.28, 4.4, const Color(0xFFEC4899), 1.1),
      (0.972, 0.74, 3.8, const Color(0xFF6366F1), 2.7),
      (0.935, 0.91, 4.6, const Color(0xFF0EA5E9), 4.2),
    ];

    for (final d in dots) {
      final dotPaint = Paint()
        ..color = d.$4.withValues(
          alpha: 0.22 + 0.14 * math.sin(t * 1.5 + d.$5),
        );
      canvas.drawCircle(
        Offset(
          size.width * d.$1 + math.cos(t + d.$5) * 8,
          size.height * d.$2 + math.sin(t * 1.2 + d.$5) * 11,
        ),
        d.$3,
        dotPaint,
      );
    }
  }

  void _drawGlowOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawEdgeRibbon(
    Canvas canvas,
    Size size, {
    required bool isLeft,
    required double phase,
    required Color color,
  }) {
    final path = Path();
    final baseX = isLeft ? 14.0 : size.width - 14.0;
    final dir = isLeft ? 1.0 : -1.0;
    const steps = 28;
    for (int i = 0; i <= steps; i++) {
      final frac = i / steps;
      final y = size.height * frac;
      final wave = math.sin(frac * math.pi * 3 + phase) * 14 * dir +
          math.cos(frac * math.pi * 2 - phase * 0.7) * 8 * dir;
      final x = baseX + wave;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  void _drawFloatingRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    bool innerRing = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius, paint);
    if (innerRing) {
      canvas.drawCircle(
        center,
        radius * 0.56,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawFloatingHexagon(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = angle + i * math.pi / 3;
      final pt = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SettingsAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
