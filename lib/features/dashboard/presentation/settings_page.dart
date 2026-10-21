import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/application/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isLoading = true;

  // Elder Settings
  bool _elderLargeFont = true;
  bool _elderHighContrast = false;
  bool _elderGentleNightWarmth = true;
  bool _elderSpokenPrompts = true;
  String _elderSpeechPace = 'gentle'; // 'gentle' or 'normal'
  bool _elderGameSounds = true;

  // Caregiver Settings
  bool _cgCognitiveAlerts = true;
  bool _cgMedicationAlerts = true;
  bool _cgMetabolicAlerts = true;
  bool _cgAudibleChime = true;
  bool _cgAutoReadPrompts = true;
  bool _cgSpeechConfidenceMeter = true;
  bool _cgAutoAdvance = false;
  bool _cgOfflineCaching = true;
  String _cgExportFormat = 'pdf'; // 'pdf' or 'fhir'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        // Elder
        _elderLargeFont = prefs.getBool('elder_large_font') ?? true;
        _elderHighContrast = prefs.getBool('elder_high_contrast') ?? false;
        _elderGentleNightWarmth = prefs.getBool('elder_gentle_night_warmth') ?? true;
        _elderSpokenPrompts = prefs.getBool('elder_spoken_prompts') ?? true;
        _elderSpeechPace = prefs.getString('elder_speech_pace') ?? 'gentle';
        _elderGameSounds = prefs.getBool('elder_game_sounds') ?? true;

        // Caregiver
        _cgCognitiveAlerts = prefs.getBool('cg_cognitive_alerts') ?? true;
        _cgMedicationAlerts = prefs.getBool('cg_medication_alerts') ?? true;
        _cgMetabolicAlerts = prefs.getBool('cg_metabolic_alerts') ?? true;
        _cgAudibleChime = prefs.getBool('cg_audible_chime') ?? true;
        _cgAutoReadPrompts = prefs.getBool('cg_auto_read_prompts') ?? true;
        _cgSpeechConfidenceMeter = prefs.getBool('cg_speech_confidence') ?? true;
        _cgAutoAdvance = prefs.getBool('cg_auto_advance') ?? false;
        _cgOfflineCaching = prefs.getBool('cg_offline_caching') ?? true;
        _cgExportFormat = prefs.getString('cg_export_format') ?? 'pdf';

        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings(bool isElder) async {
    final prefs = await SharedPreferences.getInstance();
    if (isElder) {
      await prefs.setBool('elder_large_font', _elderLargeFont);
      await prefs.setBool('elder_high_contrast', _elderHighContrast);
      await prefs.setBool('elder_gentle_night_warmth', _elderGentleNightWarmth);
      await prefs.setBool('elder_spoken_prompts', _elderSpokenPrompts);
      await prefs.setString('elder_speech_pace', _elderSpeechPace);
      await prefs.setBool('elder_game_sounds', _elderGameSounds);
    } else {
      await prefs.setBool('cg_cognitive_alerts', _cgCognitiveAlerts);
      await prefs.setBool('cg_medication_alerts', _cgMedicationAlerts);
      await prefs.setBool('cg_metabolic_alerts', _cgMetabolicAlerts);
      await prefs.setBool('cg_audible_chime', _cgAudibleChime);
      await prefs.setBool('cg_auto_read_prompts', _cgAutoReadPrompts);
      await prefs.setBool('cg_speech_confidence', _cgSpeechConfidenceMeter);
      await prefs.setBool('cg_auto_advance', _cgAutoAdvance);
      await prefs.setBool('cg_offline_caching', _cgOfflineCaching);
      await prefs.setString('cg_export_format', _cgExportFormat);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                isElder
                    ? 'Your preferences were saved successfully!'
                    : 'Clinical and system settings updated successfully!',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isElder = authState.isElder;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(authState, isElder),
              const SizedBox(height: 24),
              _buildProfileCard(authState, isElder),
              const SizedBox(height: 24),
              if (isElder) ...[
                _buildElderContent(),
              ] else ...[
                _buildCaregiverContent(),
              ],
              const SizedBox(height: 28),
              _buildActionFooter(isElder),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthState authState, bool isElder) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lilac, width: 1.2),
          ),
          child: Icon(
            isElder ? LucideIcons.heartHandshake : LucideIcons.slidersHorizontal,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isElder ? 'Personal Living & Display Settings' : 'Care Specialist Settings',
                style: AppTextStyles.h2.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                isElder
                    ? 'Adjust text sizing, audio prompts, and assistance preferences for your comfort.'
                    : 'Manage clinical notification thresholds, audio speech synthesis, and security standards.',
                style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(AuthState authState, bool isElder) {
    final name = authState.userName ?? (isElder ? 'Senior Resident' : 'Care Specialist');
    final home = authState.elderHomeName ?? 'Serenity Haven Care Facility';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : (isElder ? 'S' : 'C'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.h4.copyWith(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isElder ? AppColors.primarySoft : AppColors.riskLowBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isElder ? 'SENIOR RESIDENT' : 'STAFF CAREGIVER',
                        style: TextStyle(
                          color: isElder ? AppColors.primary : AppColors.riskLow,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isElder
                      ? 'Room ${authState.residentId != null ? 'Suite 204' : '30'} • $home'
                      : 'Facility: $home • Active Shift Duty',
                  style: AppTextStyles.caption.copyWith(color: AppColors.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ELDER VIEW CONTENT
  // -------------------------------------------------------------
  Widget _buildElderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: LucideIcons.eye,
          title: 'Easy Reading & Screen Comfort',
          subtitle: 'Adjust how text and colors look on your screen',
        ),
        const SizedBox(height: 12),
        _buildCardContainer([
          _buildToggleTile(
            icon: LucideIcons.type,
            title: 'Large & Clear Text',
            description: 'Enlarges words and buttons throughout the app for effortless reading.',
            value: _elderLargeFont,
            onChanged: (val) => setState(() => _elderLargeFont = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.contrast,
            title: 'High Contrast Mode',
            description: 'Makes letters darker and sharper against the background.',
            value: _elderHighContrast,
            onChanged: (val) => setState(() => _elderHighContrast = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.sparkles,
            title: 'Gentle Calming Colors',
            description: 'Uses soothing soft lilac and warm tones to protect your eyes.',
            value: _elderGentleNightWarmth,
            onChanged: (val) => setState(() => _elderGentleNightWarmth = val),
          ),
        ]),

        const SizedBox(height: 24),
        _buildSectionTitle(
          icon: LucideIcons.volume2,
          title: 'Spoken Audio & Voice Assistance',
          subtitle: 'Have questions and instructions read aloud to you',
        ),
        const SizedBox(height: 12),
        _buildCardContainer([
          _buildToggleTile(
            icon: LucideIcons.messageSquareQuote,
            title: 'Read Questions Out Loud',
            description: 'The app will gently speak assessment questions and daily guidance.',
            value: _elderSpokenPrompts,
            onChanged: (val) => setState(() => _elderSpokenPrompts = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.gauge, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice Reading Speed',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Choose a calm or natural speaking pace',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Slow & Gentle', style: TextStyle(fontSize: 12)),
                      selected: _elderSpeechPace == 'gentle',
                      selectedColor: AppColors.primarySoft,
                      onSelected: (sel) {
                        if (sel) setState(() => _elderSpeechPace = 'gentle');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Normal', style: TextStyle(fontSize: 12)),
                      selected: _elderSpeechPace == 'normal',
                      selectedColor: AppColors.primarySoft,
                      onSelected: (sel) {
                        if (sel) setState(() => _elderSpeechPace = 'normal');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.music,
            title: 'Uplifting Game Sounds',
            description: 'Play cheerful soft chimes when completing puzzles and memory games.',
            value: _elderGameSounds,
            onChanged: (val) => setState(() => _elderGameSounds = val),
          ),
        ]),
      ],
    );
  }

  // -------------------------------------------------------------
  // CAREGIVER VIEW CONTENT
  // -------------------------------------------------------------
  Widget _buildCaregiverContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: LucideIcons.bellRing,
          title: 'Clinical Alerts & Threshold Notifications',
          subtitle: 'Define conditions that trigger push and audible telemetry alarms',
        ),
        const SizedBox(height: 12),
        _buildCardContainer([
          _buildToggleTile(
            icon: LucideIcons.brain,
            title: 'Critical Cognitive Decline Alerts',
            description: 'Trigger immediate priority alerts when an assessment ACRF score falls below safety threshold (<70%).',
            value: _cgCognitiveAlerts,
            onChanged: (val) => setState(() => _cgCognitiveAlerts = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.pill,
            title: 'Medication Overdue Warnings',
            description: 'Show prominent alert badges and chime when a scheduled dose is 15 minutes past due on the Live Board.',
            value: _cgMedicationAlerts,
            onChanged: (val) => setState(() => _cgMedicationAlerts = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.heartPulse,
            title: 'Metabolic & Vitals Anomaly Alarms',
            description: 'Notify when recorded systolic BP exceeds 140 mmHg or sudden glucose elevation occurs.',
            value: _cgMetabolicAlerts,
            onChanged: (val) => setState(() => _cgMetabolicAlerts = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.volume2,
            title: 'Audible Chime for High-Risk Events',
            description: 'Play a distinct sound notification when an urgent medical alert is generated.',
            value: _cgAudibleChime,
            onChanged: (val) => setState(() => _cgAudibleChime = val),
          ),
        ]),

        const SizedBox(height: 24),
        _buildSectionTitle(
          icon: LucideIcons.stethoscope,
          title: 'Assessment & Clinical Tooling',
          subtitle: 'Configure guided evaluation workflows and voice synthesis',
        ),
        const SizedBox(height: 12),
        _buildCardContainer([
          _buildToggleTile(
            icon: LucideIcons.speech,
            title: 'Auto-Read Prompts to Resident',
            description: 'Automatically synthesize assessment questions into clear audio during guided evaluations.',
            value: _cgAutoReadPrompts,
            onChanged: (val) => setState(() => _cgAutoReadPrompts = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.sparkles,
            title: 'Real-time AI Speech Confidence Meter',
            description: 'Display live confidence levels and acoustic clarity indicators alongside transcribed elder speech.',
            value: _cgSpeechConfidenceMeter,
            onChanged: (val) => setState(() => _cgSpeechConfidenceMeter = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildToggleTile(
            icon: LucideIcons.fastForward,
            title: 'Auto-Advance Upon Answer Confirmation',
            description: 'Automatically advance to next question after recording a validated response.',
            value: _cgAutoAdvance,
            onChanged: (val) => setState(() => _cgAutoAdvance = val),
          ),
        ]),

        const SizedBox(height: 24),
        _buildSectionTitle(
          icon: LucideIcons.shieldCheck,
          title: 'Data Integrity, Offline Cache & Export',
          subtitle: 'Ensure HIPAA privacy compliance and reliable connectivity in care facilities',
        ),
        const SizedBox(height: 12),
        _buildCardContainer([
          _buildToggleTile(
            icon: LucideIcons.wifiOff,
            title: 'Encrypted Offline Session Caching',
            description: 'Temporarily buffer in-progress assessment telemetry locally if Wi-Fi fluctuates, auto-syncing upon reconnect.',
            value: _cgOfflineCaching,
            onChanged: (val) => setState(() => _cgOfflineCaching = val),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.fileSpreadsheet, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Clinical Report Export Format',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Format utilized for doctor sign-offs and auditing',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _cgExportFormat,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: 'pdf', child: Text('Standard PDF')),
                    DropdownMenuItem(value: 'fhir', child: Text('FHIR JSON Bundle')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _cgExportFormat = val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.lock, color: Color(0xFF0369A1), size: 18),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'HIPAA Compliance Guarantee: Zero raw voice recordings are permanently stored on cloud nodes. All acoustic feature representations are anonymized.',
                    style: TextStyle(fontSize: 12, color: AppColors.body, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // -------------------------------------------------------------
  // COMMON HELPERS
  // -------------------------------------------------------------
  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h4.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value ? AppColors.primarySoft : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.primary : AppColors.muted,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primarySoft,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(bool isElder) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              if (isElder) {
                _elderLargeFont = true;
                _elderHighContrast = false;
                _elderGentleNightWarmth = true;
                _elderSpokenPrompts = true;
                _elderSpeechPace = 'gentle';
                _elderGameSounds = true;
              } else {
                _cgCognitiveAlerts = true;
                _cgMedicationAlerts = true;
                _cgMetabolicAlerts = true;
                _cgAudibleChime = true;
                _cgAutoReadPrompts = true;
                _cgSpeechConfidenceMeter = true;
                _cgAutoAdvance = false;
                _cgOfflineCaching = true;
                _cgExportFormat = 'pdf';
              }
            });
            _saveSettings(isElder);
          },
          icon: const Icon(LucideIcons.rotateCcw, size: 15),
          label: const Text('Restore Defaults'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.body,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 14),
        ElevatedButton.icon(
          onPressed: () => _saveSettings(isElder),
          icon: const Icon(LucideIcons.save, size: 15, color: Colors.white),
          label: const Text(
            'Save Preferences',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 1,
          ),
        ),
      ],
    );
  }
}
