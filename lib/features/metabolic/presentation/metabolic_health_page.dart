import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../assessment/application/cognitive_assessment_service.dart';
import '../../auth/application/auth_controller.dart';
import '../application/metabolic_risk_service.dart';

/// Metabolic Health: run a non-diagnostic risk screening for diabetes, cardiovascular disease
/// and fatty liver, and review a resident's screening history.
class MetabolicHealthPage extends ConsumerStatefulWidget {
  final int? initialResidentId;

  /// Open with an empty form for a new screening instead of showing the latest result.
  final bool startNew;

  /// Open with the screening history section expanded.
  final bool showHistory;

  const MetabolicHealthPage({super.key, this.initialResidentId, this.startNew = false, this.showHistory = false});

  @override
  ConsumerState<MetabolicHealthPage> createState() => _MetabolicHealthPageState();
}

class _NumField {
  final String key;
  final String label;
  final String unit;

  const _NumField(this.key, this.label, this.unit);
}

const _bodyFields = [
  _NumField('age', 'Age', 'years'),
  _NumField('heightCm', 'Height', 'cm'),
  _NumField('waistCm', 'Waist', 'cm'),
  _NumField('weightKg', 'Weight', 'kg'),
];
const _vitalFields = [
  _NumField('systolicBp', 'Systolic BP', 'mmHg'),
  _NumField('diastolicBp', 'Diastolic BP', 'mmHg'),
  _NumField('restingHr', 'Resting heart rate', 'bpm'),
];
const _lifestyleFields = [
  _NumField('drinksPerWeek', 'Alcoholic drinks', 'per week'),
  _NumField('vigorousMinWeek', 'Vigorous activity', 'min / week'),
  _NumField('moderateMinWeek', 'Moderate activity incl. walking', 'min / week'),
  _NumField('sedentaryHours', 'Time sitting', 'hours / day'),
];
const _clinicFields = [
  _NumField('fastingGlucose', 'Fasting glucose', 'mg/dL'),
  _NumField('hba1c', 'HbA1c', '%'),
  _NumField('hdl', 'HDL cholesterol', 'mg/dL'),
  _NumField('ldl', 'LDL cholesterol', 'mg/dL'),
  _NumField('triglycerides', 'Triglycerides', 'mg/dL'),
];
const _extendedFields = [
  _NumField('alt', 'ALT', 'U/L'),
  _NumField('ast', 'AST', 'U/L'),
  _NumField('ggt', 'GGT', 'U/L'),
  _NumField('creatinine', 'Creatinine', 'mg/dL'),
];

const _historyFlags = {
  'toldHypertension': 'High blood pressure diagnosis',
  'toldHighCholesterol': 'High cholesterol diagnosis',
  'toldDiabetes': 'Diabetes diagnosis',
};
const _medicationFlags = {
  'onBpMeds': 'Blood pressure medication',
  'onCholesterolMeds': 'Cholesterol medication',
  'onDiabetesMeds': 'Diabetes medication',
};

const _outcomeNames = {
  'diabetes': 'Diabetes',
  'cvd': 'Heart disease & stroke',
  'fatty_liver': 'Fatty liver',
};
const _outcomeIcons = {
  'diabetes': LucideIcons.activity,
  'cvd': LucideIcons.heartPulse,
  'fatty_liver': LucideIcons.leaf,
};

/// Friendly names for the AI service's snake_case input names.
const _inputNames = {
  'age': 'age', 'sex': 'sex', 'height_cm': 'height', 'waist_cm': 'waist', 'weight_kg': 'weight',
  'systolic_bp': 'systolic BP', 'diastolic_bp': 'diastolic BP', 'resting_hr': 'resting heart rate',
  'smoking_status': 'smoking status', 'drinks_per_week': 'alcohol per week',
  'vigorous_min_week': 'vigorous activity', 'moderate_min_week': 'moderate activity',
  'sedentary_hours': 'time sitting', 'on_bp_meds': 'BP medication',
  'on_cholesterol_meds': 'cholesterol medication', 'on_diabetes_meds': 'diabetes medication',
  'told_hypertension': 'high BP diagnosis', 'told_high_cholesterol': 'high cholesterol diagnosis',
  'told_diabetes': 'diabetes diagnosis', 'fasting_glucose': 'fasting glucose', 'hba1c': 'HbA1c',
  'hdl': 'HDL', 'ldl': 'LDL', 'triglycerides': 'triglycerides', 'alt': 'ALT', 'ast': 'AST',
  'ggt': 'GGT', 'creatinine': 'creatinine', 'steps_per_day': 'steps per day', 'sleep_hours': 'sleep hours',
};

String _friendly(String key) => _inputNames[key] ?? key.replaceAll('_', ' ');


class _MetabolicHealthPageState extends ConsumerState<MetabolicHealthPage> {
  final Map<String, TextEditingController> _num = {
    for (final f in [..._bodyFields, ..._vitalFields, ..._lifestyleFields, ..._clinicFields, ..._extendedFields])
      f.key: TextEditingController(),
  };
  final Map<String, bool> _flags = {
    for (final k in [..._historyFlags.keys, ..._medicationFlags.keys]) k: false,
  };
  String? _sex;
  String? _smoking;
  // Bumped whenever the app (not the user) refills or clears the form, so the lab sections
  // re-open when prefilled values arrive but stay put while the user types.
  int _formVersion = 0;

  List<CognitiveResidentProfile> _residents = [];
  int? _residentId;
  MetabolicAssessmentRecord? _shown;
  int _totalScreenings = 0;
  // Trend points per screening id (screenings up to and including it); they never change.
  final Map<int, List<MetabolicTrendPoint>> _trends = {};

  static const _historyPageSize = 5;
  late bool _showHistory = widget.showHistory;
  MetabolicHistoryPage? _historyPage;
  DateTimeRange? _historyRange;
  bool _loadingHistoryPage = false;
  String? _historyError;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _historyKey = GlobalKey();

  bool _loadingResidents = true;
  bool _residentsRequested = false;
  ProviderSubscription<AuthNotifier>? _authSub;
  bool _loadingHistory = false;
  bool _submitting = false;
  String? _error;

  String? get _token => ref.read(authProvider).state.token;
  bool get _isElder => ref.read(authProvider).state.role == UserRole.elder;

  @override
  void initState() {
    super.initState();
    // After a page reload the auth token is restored asynchronously; wait for it before
    // loading residents, otherwise the request goes out unauthenticated.
    if (_token != null) {
      _startLoading();
    } else {
      _authSub = ref.listenManual(authProvider, (_, next) {
        if (next.state.token != null) _startLoading();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _startLoading();
      });
    }
  }

  void _startLoading() {
    if (_residentsRequested) return;
    _residentsRequested = true;
    _authSub?.close();
    _loadResidents();
  }

  @override
  void dispose() {
    _authSub?.close();
    _scroll.dispose();
    for (final c in _num.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _loadResidents() async {
    final auth = ref.read(authProvider).state;
    final residents = await CognitiveAssessmentService.fetchResidents(token: auth.token);
    if (!mounted) return;
    int? selected = widget.initialResidentId ?? (_isElder ? auth.residentId : null);
    if (selected == null || !residents.any((r) => r.id == selected)) {
      selected = residents.isNotEmpty ? residents.first.id : null;
    }
    setState(() {
      _residents = residents;
      _loadingResidents = false;
      if (residents.isEmpty) {
        _error = 'No residents are available for your account.';
      }
    });
    if (selected != null) {
      await _selectResident(selected, startNew: widget.startNew);
    }
  }

  Future<void> _selectResident(int id, {bool startNew = false}) async {
    setState(() {
      _residentId = id;
      _loadingHistory = true;
      _shown = null;
      _totalScreenings = 0;
      _historyPage = null;
      _historyRange = null;
      _historyError = null;
      _error = null;
    });
    _clearForm();
    final profile = _residents.where((r) => r.id == id).firstOrNull;
    if (profile?.age != null) {
      _num['age']!.text = profile!.age.toString();
    }
    final g = profile?.gender?.toLowerCase();
    if (g == 'male' || g == 'female') _sex = g;

    try {
      // The newest screening and the total count come from the first one-item page.
      final first = await MetabolicRiskService.fetchHistoryPage(residentId: id, size: 1, token: _token);
      if (!mounted || _residentId != id) return;
      final latest = first.items.isNotEmpty ? first.items.first : null;
      setState(() {
        _totalScreenings = first.totalItems;
        _shown = latest != null && !startNew ? latest : null;
      });
      if (_shown != null) _loadTrend(_shown!);
      if (_showHistory) _loadHistoryPage(0);
      if (latest != null) {
        final last = latest.inputs;
        // A new screening keeps only attributes that do not change between visits.
        _fillForm(startNew ? {for (final k in const ['sex', 'heightCm']) if (last[k] != null) k: last[k]} : last);
      }
    } on MetabolicApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadHistoryPage(int page) async {
    final id = _residentId;
    if (id == null) return;
    setState(() {
      _loadingHistoryPage = true;
      _historyError = null;
    });
    try {
      final range = _historyRange;
      final result = await MetabolicRiskService.fetchHistoryPage(
          residentId: id, page: page, size: _historyPageSize, from: range?.start, to: range?.end, token: _token);
      if (!mounted || _residentId != id || range != _historyRange) return;
      setState(() {
        _historyPage = result;
        if (range == null) _totalScreenings = result.totalItems;
      });
    } on MetabolicApiException catch (e) {
      if (mounted) setState(() => _historyError = e.message);
    } finally {
      if (mounted) setState(() => _loadingHistoryPage = false);
    }
  }

  Future<void> _pickHistoryRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _historyRange,
      helpText: 'Show screenings between',
      saveText: 'Apply',
      // Show as a centred dialog rather than a full-screen page on wide screens.
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _historyRange = picked);
    _loadHistoryPage(0);
  }

  void _clearHistoryRange() {
    setState(() => _historyRange = null);
    _loadHistoryPage(0);
  }

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
    if (_showHistory) {
      if (_historyPage == null) _loadHistoryPage(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _historyKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        }
      });
    }
  }

  /// Show a past screening in the results panel (and its inputs in the form).
  void _viewRecord(MetabolicAssessmentRecord rec) {
    setState(() => _shown = rec);
    _loadTrend(rec);
    _fillForm(rec.inputs);
    _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  Future<void> _loadTrend(MetabolicAssessmentRecord rec) async {
    if (_trends.containsKey(rec.id)) return;
    try {
      final points = await MetabolicRiskService.fetchTrend(
          residentId: rec.residentId, assessmentId: rec.id, token: _token);
      if (mounted) setState(() => _trends[rec.id] = points);
    } on MetabolicApiException {
      // The trend is supplementary; the result card still shows without it.
    }
  }

  void _clearForm() {
    for (final c in _num.values) {
      c.clear();
    }
    for (final k in _flags.keys) {
      _flags[k] = false;
    }
    _sex = null;
    _smoking = null;
    _formVersion++;
  }

  /// Pre-fill the form with the inputs of a previous screening.
  void _fillForm(Map<String, dynamic> inputs) {
    setState(() {
      inputs.forEach((key, value) {
        if (_num.containsKey(key) && value is num) {
          _num[key]!.text = value % 1 == 0 ? value.toInt().toString() : value.toString();
        } else if (_flags.containsKey(key) && value is bool) {
          _flags[key] = value;
        }
      });
      if (inputs['sex'] is String) _sex = inputs['sex'] as String;
      if (inputs['smokingStatus'] is String) _smoking = inputs['smokingStatus'] as String;
      _formVersion++;
    });
  }

  double? _value(String key) => double.tryParse(_num[key]!.text.trim());

  Future<void> _submit() async {
    final id = _residentId;
    if (id == null) return;
    if (_sex == null) {
      setState(() => _error = 'Please choose the resident\'s sex; the models need it.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final inputs = MetabolicInputs(
      age: _value('age'),
      sex: _sex,
      heightCm: _value('heightCm'),
      weightKg: _value('weightKg'),
      waistCm: _value('waistCm'),
      systolicBp: _value('systolicBp'),
      diastolicBp: _value('diastolicBp'),
      restingHr: _value('restingHr'),
      smokingStatus: _smoking,
      drinksPerWeek: _value('drinksPerWeek'),
      vigorousMinWeek: _value('vigorousMinWeek'),
      moderateMinWeek: _value('moderateMinWeek'),
      sedentaryHours: _value('sedentaryHours'),
      onBpMeds: _flags['onBpMeds'],
      onCholesterolMeds: _flags['onCholesterolMeds'],
      onDiabetesMeds: _flags['onDiabetesMeds'],
      toldHypertension: _flags['toldHypertension'],
      toldHighCholesterol: _flags['toldHighCholesterol'],
      toldDiabetes: _flags['toldDiabetes'],
      fastingGlucose: _value('fastingGlucose'),
      hba1c: _value('hba1c'),
      hdl: _value('hdl'),
      ldl: _value('ldl'),
      triglycerides: _value('triglycerides'),
      alt: _value('alt'),
      ast: _value('ast'),
      ggt: _value('ggt'),
      creatinine: _value('creatinine'),
    );
    try {
      final record = await MetabolicRiskService.submitAssessment(residentId: id, inputs: inputs, token: _token);
      if (!mounted) return;
      setState(() {
        _shown = record;
        _totalScreenings += 1;
      });
      _loadTrend(record);
      if (_showHistory) _loadHistoryPage(0);
    } on MetabolicApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ------------------------------------------------------------------ layout

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 16),
          _disclaimerBanner(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _messageBox(_error!, AppColors.riskHigh, AppColors.riskHighBg, LucideIcons.alertCircle),
          ],
          const SizedBox(height: 20),
          if (_loadingResidents)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_residentId != null)
            LayoutBuilder(builder: (context, constraints) {
              final form = _formCard();
              final results = _resultsPanel();
              if (constraints.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: form),
                    const SizedBox(width: 24),
                    Expanded(flex: 6, child: results),
                  ],
                );
              }
              return Column(children: [form, const SizedBox(height: 20), results]);
            }),
          if (!_loadingResidents && _residentId != null) ...[
            const SizedBox(height: 24),
            _historySection(),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.activity, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metabolic Health', style: AppTextStyles.h2),
                const SizedBox(height: 2),
                Text('Diabetes, heart disease and fatty liver risk screening', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
        if (!_isElder && _residents.length > 1) _residentPicker(),
      ],
    );
  }

  Widget _residentPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _residentId,
          icon: const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.primary),
          style: const TextStyle(fontSize: 13, color: AppColors.navy, fontWeight: FontWeight.w600),
          items: [
            for (final r in _residents)
              DropdownMenuItem(
                value: r.id,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.user, size: 13, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('${r.name.trim().isEmpty ? 'Resident #${r.id}' : r.name.trim()} · ${r.roomNumber}'),
                ]),
              ),
          ],
          onChanged: _submitting ? null : (id) => id != null ? _selectResident(id) : null,
        ),
      ),
    );
  }

  Widget _disclaimerBanner() {
    return _messageBox(
      'Screening estimates from models trained on US survey data (NHANES 2013-2018, adults 40+). '
      'They describe how common a condition is among people with similar measurements. '
      'They are not a diagnosis and do not replace a doctor\'s assessment.',
      AppColors.primary,
      AppColors.primarySoft,
      LucideIcons.info,
    );
  }

  Widget _messageBox(String text, Color fg, Color bg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.navy))),
      ]),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      );

  // ------------------------------------------------------------------ form

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Screening inputs', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text('Home measurements are enough for an estimate. Adding blood tests makes it more precise.',
              style: AppTextStyles.caption),
          const SizedBox(height: 18),
          _sectionTitle('About the resident'),
          _choiceRow('Sex', const {'female': 'Female', 'male': 'Male'}, _sex, (v) => setState(() => _sex = v)),
          const SizedBox(height: 12),
          _fieldWrap(_bodyFields),
          const SizedBox(height: 18),
          _sectionTitle('Blood pressure & heart rate'),
          _fieldWrap(_vitalFields),
          const SizedBox(height: 18),
          _sectionTitle('Lifestyle'),
          _choiceRow('Smoking', const {'never': 'Never', 'former': 'Former', 'current': 'Current'}, _smoking,
              (v) => setState(() => _smoking = v)),
          const SizedBox(height: 12),
          _fieldWrap(_lifestyleFields),
          const SizedBox(height: 18),
          _sectionTitle('Medical history (ever told by a doctor)'),
          _flagWrap(_historyFlags),
          const SizedBox(height: 14),
          _sectionTitle('Currently taking'),
          _flagWrap(_medicationFlags),
          const SizedBox(height: 10),
          _labSection('Clinic blood tests (fasting)', 'Unlocks the clinic model', _clinicFields),
          _labSection('Extended blood tests', 'Liver enzymes and kidney function', _extendedFields),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _submitting || _loadingHistory ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.stethoscope, size: 18),
                label: Text(_submitting ? 'Running screening...' : 'Run screening'),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _submitting ? null : () => setState(_clearForm),
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Clear'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: AppTextStyles.h4.copyWith(fontSize: 14)),
      );

  Widget _fieldWrap(List<_NumField> fields) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final f in fields)
          SizedBox(
            width: 190,
            child: TextField(
              key: ValueKey('metabolic-${f.key}'),
              controller: _num[f.key],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: InputDecoration(
                labelText: f.label,
                suffixText: f.unit,
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _choiceRow(String label, Map<String, String> options, String? value, ValueChanged<String?> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 70, child: Text(label, style: AppTextStyles.bodySmall)),
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: value == e.key,
            selectedColor: AppColors.primarySoft,
            labelStyle: TextStyle(
              color: value == e.key ? AppColors.primaryDeep : AppColors.body,
              fontWeight: value == e.key ? FontWeight.w600 : FontWeight.w400,
            ),
            onSelected: (sel) => onChanged(sel ? e.key : null),
          ),
      ],
    );
  }

  Widget _flagWrap(Map<String, String> flags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in flags.entries)
          FilterChip(
            label: Text(e.value),
            selected: _flags[e.key]!,
            selectedColor: AppColors.primarySoft,
            checkmarkColor: AppColors.primaryDeep,
            onSelected: (sel) => setState(() => _flags[e.key] = sel),
          ),
      ],
    );
  }

  Widget _labSection(String title, String subtitle, List<_NumField> fields) {
    final hasValues = fields.any((f) => _num[f.key]!.text.isNotEmpty);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // A plain key: a PageStorageKey here is shared with the TextFields' scroll state
        // inside the tile and makes them read the tile's bool as a scroll offset.
        key: ValueKey('lab-$title-$_residentId-$_formVersion'),
        initiallyExpanded: hasValues,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 14)),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        // Top padding keeps the first row's floating labels inside the tile's clip area.
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(alignment: Alignment.centerLeft, child: _fieldWrap(fields)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ results

  Widget _resultsPanel() {
    if (_loadingHistory) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: _cardDecoration,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final record = _shown;
    if (record == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration,
        child: Column(children: [
          const Icon(LucideIcons.clipboardList, size: 32, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(_totalScreenings == 0 ? 'No screening yet for this resident' : 'New screening', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          Text(
              _totalScreenings == 0
                  ? 'Fill in the inputs and run a screening to see risk tiers and reasons.'
                  : 'Enter today\'s measurements and run the screening. Use "See history" below for earlier results.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Screening result', style: AppTextStyles.h3)),
            Text(_formatDate(record.createdAt), style: AppTextStyles.caption),
          ]),
          if (record.assessedBy != null) ...[
            const SizedBox(height: 2),
            Text('By ${record.assessedBy}', style: AppTextStyles.caption),
          ],
          if (record.inputWarnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _messageBox(record.inputWarnings.join('\n'), AppColors.riskModerate, AppColors.riskModerateBg,
                LucideIcons.alertTriangle),
          ],
          const SizedBox(height: 16),
          for (final o in record.outcomes) ...[_outcomeCard(o), const SizedBox(height: 14)],
          if (record.inputsNotUsed.isNotEmpty)
            Text('Recorded but not used by the current models: ${record.inputsNotUsed.map(_friendly).join(', ')}.',
                style: AppTextStyles.caption),
        ],
      ),
    );
  }

  (Color, Color, String) _tierStyle(String? tier) {
    switch (tier) {
      case 'high':
        return (AppColors.riskHigh, AppColors.riskHighBg, 'High');
      case 'watch':
        return (AppColors.riskModerate, AppColors.riskModerateBg, 'Watch');
      case 'low':
        return (AppColors.riskLow, AppColors.riskLowBg, 'Low');
      default:
        return (AppColors.muted, AppColors.surfaceSecondary, '—');
    }
  }

  Widget _tierPill(String? tier, {bool small = false}) {
    final (fg, bg, label) = _tierStyle(tier);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 11 : 12.5)),
    );
  }

  Widget _outcomeCard(MetabolicOutcomeResult o) {
    final name = _outcomeNames[o.key] ?? o.title ?? o.key;
    final (accent, _, _) = _tierStyle(o.riskTier);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: o.isOk ? accent : AppColors.border, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_outcomeIcons[o.key] ?? LucideIcons.activity, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: AppTextStyles.h4)),
            if (o.isOk) _tierPill(o.riskTier),
          ]),
          const SizedBox(height: 8),
          if (o.status == 'insufficient_information' && o.missingInputs.isNotEmpty)
            Text('Not enough information for an estimate. Please add: ${o.missingInputs.map(_friendly).join(', ')}.',
                style: AppTextStyles.bodySmall)
          else if (o.status == 'not_applicable' || o.status == 'insufficient_information')
            Text(o.message ?? 'No estimate available.', style: AppTextStyles.bodySmall)
          else ...[
            Text(_capitalize(o.riskRange ?? ''),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.navy, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${o.tierText ?? ''}  Based on ${o.modelTier ?? 'home'} inputs.', style: AppTextStyles.caption),
            _trendStrip(o),
            if (o.topReasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Main reasons', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final r in o.topReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(LucideIcons.arrowUpRight, size: 15, color: AppColors.body),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r.reason, style: AppTextStyles.bodySmall)),
                  ]),
                ),
            ],
            if (o.suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Suggested next steps', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final s in o.suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(LucideIcons.lightbulb, size: 15, color: AppColors.accentTeal),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s, style: AppTextStyles.bodySmall)),
                  ]),
                ),
            ],
            if (o.note != null) ...[
              const SizedBox(height: 8),
              Text('${o.note} Estimated: ${o.estimatedInputs.map(_friendly).join(', ')}.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.riskModerate)),
            ],
            if (o.inputsToImprove.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('For a more precise estimate, add: ${o.inputsToImprove.map(_friendly).join(', ')}.',
                  style: AppTextStyles.caption),
            ],
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ history (full width, paginated)

  // ------------------------------------------------------------------ trend in each result card

  Widget _trendStrip(MetabolicOutcomeResult o) {
    final points = _shown == null ? null : _trends[_shown!.id];
    if (points == null) return const SizedBox.shrink();
    final series = [
      for (final p in points)
        if (p.outcomes[o.key]?.probability != null) (p, p.outcomes[o.key]!),
    ];
    if (series.length < 2) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('First screening for this outcome. A trend appears after the next one.',
            style: AppTextStyles.caption),
      );
    }
    final current = series.last.$2.probability!;
    final previous = series[series.length - 2];
    final diff = ((current - previous.$2.probability!) * 100).round();
    // Show the time too when several screenings share a date, so each point is identifiable.
    final days = series.map((s) => _formatShortDate(s.$1.createdAt)).toList();
    final withTime = days.toSet().length < days.length;
    final since = _formatShortDate(previous.$1.createdAt, withTime: withTime);
    final (Color changeColor, String changeText) = diff > 0
        ? (const Color(0xFFB91C1C), '▲ $diff from $since')
        : diff < 0
            ? (const Color(0xFF15803D), '▼ ${-diff} from $since')
            : (AppColors.body, 'No change from $since');
    final tooltip = series
        .map((s) => '${_formatShortDate(s.$1.createdAt, withTime: withTime)}: ${(s.$2.probability! * 100).round()} in 100'
            '${s.$2.riskTier != null ? ' (${_tierStyle(s.$2.riskTier).$3})' : ''}')
        .join('\n');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Tooltip(
          message: tooltip,
          child: Semantics(
            label: 'Trend over the last ${series.length} screenings: $tooltip',
            child: SizedBox(
              width: 150,
              height: 40,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: [for (final s in series) s.$2.probability!],
                  lineColor: AppColors.primary,
                  lastColor: _tierStyle(o.riskTier).$1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Last ${series.length} screenings', style: AppTextStyles.caption),
            const SizedBox(height: 2),
            Text(changeText,
                style: AppTextStyles.bodySmall.copyWith(color: changeColor, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _historySection() {
    final page = _historyPage;
    return Container(
      key: _historyKey,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.history, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Screening history${_totalScreenings > 0 ? ' ($_totalScreenings)' : ''}',
                style: AppTextStyles.h4,
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('metabolic-see-history'),
              onPressed: _totalScreenings == 0 && !_showHistory ? null : _toggleHistory,
              icon: Icon(_showHistory ? LucideIcons.eyeOff : LucideIcons.history, size: 15),
              label: Text(_showHistory ? 'Hide history' : 'See history'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          if (!_showHistory && _totalScreenings == 0) ...[
            const SizedBox(height: 8),
            Text('No previous screenings for this resident.', style: AppTextStyles.caption),
          ],
          if (_showHistory) ...[
            const SizedBox(height: 14),
            _historyFilterBar(),
            const SizedBox(height: 14),
            if (_historyError != null)
              _messageBox(_historyError!, AppColors.riskHigh, AppColors.riskHighBg, LucideIcons.alertCircle)
            else if (page == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (page.items.isEmpty)
              Text(
                _historyRange == null
                    ? 'No previous screenings for this resident.'
                    : 'No screenings between ${_formatDay(_historyRange!.start)} and ${_formatDay(_historyRange!.end)}.',
                style: AppTextStyles.caption,
              )
            else ...[
              AnimatedOpacity(
                opacity: _loadingHistoryPage ? 0.45 : 1,
                duration: const Duration(milliseconds: 150),
                child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return Column(children: [
                    if (wide) _historyHeaderRow(),
                    for (final rec in page.items) wide ? _historyRowWide(rec) : _historyRowCompact(rec),
                  ]);
                }),
              ),
              const SizedBox(height: 14),
              _paginationBar(page),
            ],
          ],
        ],
      ),
    );
  }

  Widget _historyFilterBar() {
    final range = _historyRange;
    final label = range == null
        ? 'All dates'
        : range.start == range.end
            ? _formatDay(range.start)
            : '${_formatDay(range.start)} – ${_formatDay(range.end)}';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Date', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        OutlinedButton.icon(
          key: const ValueKey('metabolic-history-date-filter'),
          onPressed: _pickHistoryRange,
          icon: const Icon(LucideIcons.calendar, size: 15),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: range == null ? AppColors.body : AppColors.primaryDeep,
            backgroundColor: range == null ? Colors.transparent : AppColors.primarySoft,
            side: BorderSide(color: range == null ? AppColors.border : AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Clear date filter',
            onPressed: _clearHistoryRange,
            icon: const Icon(LucideIcons.x, size: 16, color: AppColors.muted),
          ),
      ],
    );
  }

  static const _historyFlex = [3, 4, 3, 3, 3, 2];

  Widget _historyHeaderRow() {
    const labels = ['Date', 'Screened by', 'Diabetes', 'Heart disease & stroke', 'Fatty liver', ''];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            flex: _historyFlex[i],
            child: Text(labels[i], style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  MetabolicOutcomeResult? _outcome(MetabolicAssessmentRecord rec, String key) =>
      rec.outcomes.where((o) => o.key == key).firstOrNull;

  Widget _historyTierCell(MetabolicOutcomeResult? o) {
    final ok = o != null && o.isOk;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _tierPill(ok ? o.riskTier : null, small: true),
      if (ok && o.probability != null) ...[
        const SizedBox(width: 6),
        Text('${(o.probability! * 100).round()} in 100', style: AppTextStyles.caption),
      ],
    ]);
  }

  Widget _viewButton(MetabolicAssessmentRecord rec) {
    final selected = _shown?.id == rec.id;
    return TextButton(
      onPressed: selected ? null : () => _viewRecord(rec),
      child: Text(selected ? 'Showing' : 'View'),
    );
  }

  Widget _historyRowWide(MetabolicAssessmentRecord rec) {
    final selected = _shown?.id == rec.id;
    final cells = <Widget>[
      Text(_formatDate(rec.createdAt), style: AppTextStyles.bodySmall.copyWith(color: AppColors.navy)),
      Text(rec.assessedBy ?? '-', style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
      _historyTierCell(_outcome(rec, 'diabetes')),
      _historyTierCell(_outcome(rec, 'cvd')),
      _historyTierCell(_outcome(rec, 'fatty_liver')),
      Align(alignment: Alignment.centerRight, child: _viewButton(rec)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(flex: _historyFlex[i], child: Align(alignment: Alignment.centerLeft, child: cells[i])),
      ]),
    );
  }

  Widget _historyRowCompact(MetabolicAssessmentRecord rec) {
    final selected = _shown?.id == rec.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_formatDate(rec.createdAt), style: AppTextStyles.bodySmall.copyWith(color: AppColors.navy))),
          _viewButton(rec),
        ]),
        Text(rec.assessedBy ?? '', style: AppTextStyles.caption),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final key in MetabolicAssessmentRecord.outcomeOrder)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${_outcomeNames[key]} ', style: AppTextStyles.caption),
              _historyTierCell(_outcome(rec, key)),
            ]),
        ]),
      ]),
    );
  }

  Widget _paginationBar(MetabolicHistoryPage page) {
    final from = page.page * page.size + 1;
    final to = from + page.items.length - 1;
    final last = page.totalPages - 1;
    // Show up to 5 page numbers around the current page.
    final start = (page.page - 2).clamp(0, (last - 4).clamp(0, last));
    final end = (start + 4).clamp(0, last);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      spacing: 12,
      children: [
        Text(
          'Showing $from–$to of ${page.totalItems}${_historyRange != null ? ' in the selected dates' : ''}',
          style: AppTextStyles.caption,
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page.page > 0 && !_loadingHistoryPage ? () => _loadHistoryPage(page.page - 1) : null,
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
          ),
          for (var i = start; i <= end; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                width: 34,
                height: 34,
                child: TextButton(
                  onPressed: i == page.page || _loadingHistoryPage ? null : () => _loadHistoryPage(i),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: i == page.page ? AppColors.primary : Colors.transparent,
                    disabledForegroundColor: i == page.page ? Colors.white : AppColors.muted,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page.page < last && !_loadingHistoryPage ? () => _loadHistoryPage(page.page + 1) : null,
            icon: const Icon(LucideIcons.chevronRight, size: 18),
          ),
        ]),
      ],
    );
  }

  static String _formatDay(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _formatShortDate(DateTime? d, {bool withTime = false}) {
    if (d == null) return 'the previous screening';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = '${d.day} ${months[d.month - 1]}';
    if (!withTime) return day;
    return '$day, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _formatDate(DateTime? d) {
    if (d == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }
}

/// Small line of one outcome's probability across screenings; the last point is coloured by tier.
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color lastColor;

  _SparklinePainter({required this.values, required this.lineColor, required this.lastColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const pad = 6.0;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    // Keep at least 10 points of range so small wobbles do not look like big swings.
    if (hi - lo < 0.10) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.05;
      hi = mid + 0.05;
    }
    final dx = (size.width - 2 * pad) / (values.length - 1);
    Offset at(int i) => Offset(
          pad + i * dx,
          pad + (1 - (values[i] - lo) / (hi - lo)) * (size.height - 2 * pad),
        );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = lineColor;
    for (var i = 0; i < values.length - 1; i++) {
      canvas.drawCircle(at(i), 2.5, dot);
    }
    final last = at(values.length - 1);
    canvas.drawCircle(last, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 4, Paint()..color = lastColor);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.lineColor != lineColor || old.lastColor != lastColor || !_sameValues(old.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
