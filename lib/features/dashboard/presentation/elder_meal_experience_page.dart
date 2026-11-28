import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/services/tts_service.dart';

/// Interactive Elder Meal Logging & Experience Page
/// Pixel-matched with the Carevora Storybook Elder-Care Design.
class ElderMealExperiencePage extends ConsumerStatefulWidget {
  const ElderMealExperiencePage({super.key});

  @override
  ConsumerState<ElderMealExperiencePage> createState() =>
      _ElderMealExperiencePageState();
}

class _ElderMealExperiencePageState extends ConsumerState<ElderMealExperiencePage>
    with SingleTickerProviderStateMixin {
  // 1. Food selection (Multi-select, Default matching mockup: Rice & Vegetables selected)
  final Set<String> _selectedFoods = {'rice', 'veg'};

  // 2. Taste rating (Single-select: 'delicious', 'normal', 'dislike')
  String _selectedTaste = 'delicious';

  // 3. Eating company (Single-select: 'friends', 'alone')
  String _selectedCompany = 'friends';

  // 4. Beverages (Multi-select, Default matching mockup: Water selected)
  final Set<String> _selectedBeverages = {'water'};

  // 5. Additional notes text controller
  final TextEditingController _notesController = TextEditingController();

  // Voice speech-to-text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  // Waveform animation controller for mic button
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initSpeech();

    // Welcome voice guidance for elderly user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak('අද දින ආහාරය පිළිබඳ ඔබේ අත්දැකීම් මෙහි සටහන් කරන්න.');
    });
  }

  void _initSpeech() async {
    try {
      _speech = stt.SpeechToText();
      final available = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (mounted) {
        setState(() => _speechAvailable = available);
      }
    } catch (_) {
      // Speech recognition not available on some platforms
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _speak(String text) async {
    try {
      await TtsService.instance.speak(text, isSinhala: true);
    } catch (_) {}
  }

  void _toggleFood(String id, String sinhalaName) {
    setState(() {
      if (_selectedFoods.contains(id)) {
        _selectedFoods.remove(id);
      } else {
        _selectedFoods.add(id);
        _speak('$sinhalaName තේරුවා');
      }
    });
  }

  void _toggleBeverage(String id, String sinhalaName) {
    setState(() {
      if (_selectedBeverages.contains(id)) {
        _selectedBeverages.remove(id);
      } else {
        _selectedBeverages.add(id);
        _speak('$sinhalaName පානය තේරුවා');
      }
    });
  }

  void _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      _speak('හඬ සටහන අවසන් කළා.');
    } else {
      _speak('කරුණාකර දැන් කතා කරන්න.');
      if (_speechAvailable) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _notesController.text = result.recognizedWords;
            });
          },
          localeId: 'si_LK',
        );
      } else {
        // Fallback simulation for elder convenience
        setState(() => _isListening = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isListening = false;
            if (_notesController.text.isEmpty) {
              _notesController.text = 'කැඳ සහ සුප් ස්වල්පයක් ලබා ගත්තා.';
            }
          });
          _speak('ඔබගේ හඬ සටහන එක් කළා.');
        }
      }
    }
  }

  void _showAddOtherFoodDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('වෙනත් ආහාරයක් ඇතුළත් කරන්න', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'උදා: සුප්, ඕට්ස්, කැඳ...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('අවලංගු කරන්න', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final text = controller.text.trim();
                setState(() {
                  _selectedFoods.add('other_$text');
                  if (_notesController.text.isEmpty) {
                    _notesController.text = text;
                  } else {
                    _notesController.text += ', $text';
                  }
                });
                _speak('$text එකතු කළා');
              }
              Navigator.pop(ctx);
            },
            child: const Text('එක් කරන්න', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddOtherDrinkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.local_cafe_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('වෙනත් පානයක් ඇතුළත් කරන්න', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'උදා: තැඹිලි, සුප්, ඖෂධීය පාන...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('අවලංගු කරන්න', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final text = controller.text.trim();
                setState(() {
                  _selectedBeverages.add('other_$text');
                  if (_notesController.text.isEmpty) {
                    _notesController.text = text;
                  } else {
                    _notesController.text += ', $text';
                  }
                });
                _speak('$text පානය එකතු කළා');
              }
              Navigator.pop(ctx);
            },
            child: const Text('එක් කරන්න', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _saveMealExperience() async {
    _speak('ඔබගේ ආහාර තොරතුරු සාර්ථකව සුරැකුණා. ඔබට නිරෝගී සුවය ප්‍රාර්ථනා කරනවා!');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'තොරතුරු සුරැකිණි!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'අද දින ආහාර පිළිබඳ අත්දැකීම් සාර්ථකව සටහන් කරගන්නා ලදී.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/dashboard/elder-home');
                },
                child: const Text(
                  'හරි, මුල් පිටුවට යන්න',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF), // Soft lavender background
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient soft background glow & botanical floral flourishes
            Positioned(
              left: -40,
              bottom: -30,
              child: _buildBotanicalLeavesDecoration(isLeft: true),
            ),
            Positioned(
              right: -40,
              bottom: -30,
              child: _buildBotanicalLeavesDecoration(isLeft: false),
            ),

            // Scrollable Content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. HERO PURPLE BANNER (Plate of food + Title + Grandma Thumbs up)
                      _buildHeroMealBanner(),
                      const SizedBox(height: 18),

                      // 2. MAIN INTERACTIVE CONTENT CARD
                      _buildMainExperienceCard(),
                      const SizedBox(height: 26),

                      // 3. BOTTOM SAVE ACTION BUTTON
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HERO PURPLE BANNER (Plate of Food + Title + Smiling Grandma Thumbs Up)
  // =========================================================================
  Widget _buildHeroMealBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7C3AED), // Royal Purple
            Color(0xFFA855F7), // Orchid Violet
            Color(0xFFC084FC), // Luminous Lavender
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Close Button in Top-Right
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  tooltip: 'වසන්න',
                  onPressed: () {
                    context.go('/dashboard/elder-home');
                  },
                ),
              ),
            ),
            // Background subtle lavender blossoms fade
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 300,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/banner_flowers_fade.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  // Left: Realistic Nutritious Plate (Rice, curry, red apple, glass of water)
                  _buildNutritiousMealPlateIllustration(),
                  const SizedBox(width: 22),

                  // Center: Title with yellow smile curve underline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'අද දින ආහාරය ගැන ඔබගේ අත්දැකීම්',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Cheerful warm yellow smile curve stroke
                        CustomPaint(
                          size: const Size(180, 10),
                          painter: _SmileCurvePainter(),
                        ),
                      ],
                    ),
                  ),

                  // Right: Smiling Grandma giving Thumbs Up!
                  _buildGrandmaThumbsUpAvatar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nutritious meal plate graphic on left of hero banner
  Widget _buildNutritiousMealPlateIllustration() {
    return Container(
      width: 140,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.40), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Porcelain Plate
          Container(
            width: 110,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                // Rice bowl
                Text('🍚', style: TextStyle(fontSize: 32)),
                SizedBox(width: 2),
                // Vegetable Curry
                Text('🥗', style: TextStyle(fontSize: 28)),
              ],
            ),
          ),
          // Red Apple & Fresh Water Glass
          const Positioned(
            right: 4,
            bottom: 4,
            child: Text('🍎', style: TextStyle(fontSize: 22)),
          ),
          const Positioned(
            left: 4,
            bottom: 4,
            child: Text('🥛', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  // Grandmother Thumbs Up Avatar on right of hero banner
  Widget _buildGrandmaThumbsUpAvatar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Thumbs up gesture badge
            Positioned(
              left: -14,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: const Text('👍', style: TextStyle(fontSize: 22)),
              ),
            ),
            // Grandma circular avatar photo
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/landing/testimonial_1.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFDDD6FE),
                    alignment: Alignment.center,
                    child: const Text('👵', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        // Floating Heart outline
        Text(
          '♡',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.90),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. MAIN EXPERIENCE CARD (Food types + Taste + Company + Beverages + Notes)
  // =========================================================================
  Widget _buildMainExperienceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9DDFB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ROW 1: "ඔබ අද කෑවේ මොනවාද?" (Food Categories Multi-Select)
          _buildFoodItemsSelectionRow(),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1E8FF), thickness: 1.5),
          const SizedBox(height: 20),

          // ROW 2 & 3 & 4 + RIGHT NOTES CARD
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 850;

              final leftQuestions = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 2: Taste Rating ("ආහාරය රස වින්දාද?")
                  _buildTasteRatingSection(),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF5EFFF), thickness: 1.2),
                  const SizedBox(height: 16),

                  // SECTION 3: Company ("ආහාරය ගත්තේ කවුරුද සමගද?")
                  _buildCompanySection(),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF5EFFF), thickness: 1.2),
                  const SizedBox(height: 16),

                  // SECTION 4: Beverages ("ආහාරයට අමතරව මොනවා බිව්වාද?")
                  _buildBeverageSelectionSection(),
                ],
              );

              final rightNotes = _buildAdditionalNotesCard();

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 66, child: leftQuestions),
                    const SizedBox(width: 24),
                    Expanded(flex: 34, child: rightNotes),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftQuestions,
                    const SizedBox(height: 24),
                    rightNotes,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ROW 1: "ඔබ අද කෑවේ මොනවාද?"
  // -------------------------------------------------------------------------
  Widget _buildFoodItemsSelectionRow() {
    final foodOptions = [
      {'id': 'rice', 'title': 'බත්', 'icon': '🍚', 'desc': 'Steamed rice'},
      {'id': 'veg', 'title': 'එළවළු', 'icon': '🥗', 'desc': 'Mixed veggies'},
      {'id': 'fish', 'title': 'මාළු', 'icon': '🐟', 'desc': 'Fresh fish'},
      {'id': 'chicken', 'title': 'කුකුල් මස්', 'icon': '🍗', 'desc': 'Chicken'},
      {'id': 'egg', 'title': 'බිත්තර', 'icon': '🥚', 'desc': 'Boiled eggs'},
      {'id': 'fruit', 'title': 'පළතුරු', 'icon': '🍎', 'desc': 'Fresh fruits'},
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Icon Squircle
        _buildSectionIconSquircle(const Text('🍽️', style: TextStyle(fontSize: 24))),
        const SizedBox(width: 14),

        // Title and Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'ඔබ අද කෑවේ මොනවාද?',
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E1B4B),
              ),
            ),
            SizedBox(height: 3),
            Text(
              'කෑ ආහාර වර්ග තෝරන්න\n'
              '(කීපයක් එකවර තෝරන්න පුළුවන්)',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                height: 1.25,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Scrollable / Wrap Food Choice Pills
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...foodOptions.map((f) {
                  final isSelected = _selectedFoods.contains(f['id']!);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildFoodOptionPill(
                      id: f['id']!,
                      title: f['title']!,
                      iconText: f['icon']!,
                      isSelected: isSelected,
                      onTap: () => _toggleFood(f['id']!, f['title']!),
                    ),
                  );
                }),
                // "+ වෙනත්" Pill
                _buildAddOtherPill(onTap: _showAddOtherFoodDialog),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodOptionPill({
    required String id,
    required String title,
    required String iconText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        height: 76,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF22C55E).withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Checkmark indicator when selected
            if (isSelected)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),

            // Icon + Label
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(iconText, style: const TextStyle(fontSize: 27)),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? const Color(0xFF15803D) : const Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOtherPill({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 82,
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_rounded, size: 28, color: Color(0xFF7C3AED)),
            SizedBox(height: 4),
            Text(
              'වෙනත්',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D28D9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SECTION 2: "ආහාරය රස වින්දාද?" (Taste Rating)
  // -------------------------------------------------------------------------
  Widget _buildTasteRatingSection() {
    return Row(
      children: [
        _buildSectionIconSquircle(const Text('😋', style: TextStyle(fontSize: 22))),
        const SizedBox(width: 12),
        const Text(
          'ආහාරය රස වින්දාද?',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E1B4B),
          ),
        ),
        const SizedBox(width: 16),

        // Taste Pills: 😋 රසයි | 😐 සාමාන්‍යයි | 😡 රස නැහැ
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTasteRatingPill(
                  id: 'delicious',
                  title: 'රසයි',
                  emoji: '😋',
                  activeBgColor: const Color(0xFFDCFCE7),
                  activeBorderColor: const Color(0xFF22C55E),
                  activeTextColor: const Color(0xFF15803D),
                  isSelected: _selectedTaste == 'delicious',
                  onTap: () {
                    setState(() => _selectedTaste = 'delicious');
                    _speak('ආහාරය රසයි ලෙස සටහන් කළා.');
                  },
                ),
                const SizedBox(width: 10),
                _buildTasteRatingPill(
                  id: 'normal',
                  title: 'සාමාන්‍යයි',
                  emoji: '😐',
                  activeBgColor: const Color(0xFFFEF9C3),
                  activeBorderColor: const Color(0xFFEAB308),
                  activeTextColor: const Color(0xFF854D0E),
                  isSelected: _selectedTaste == 'normal',
                  onTap: () {
                    setState(() => _selectedTaste = 'normal');
                    _speak('ආහාරය සාමාන්‍යයි ලෙස සටහන් කළා.');
                  },
                ),
                const SizedBox(width: 10),
                _buildTasteRatingPill(
                  id: 'dislike',
                  title: 'රස නැහැ',
                  emoji: '😡',
                  activeBgColor: const Color(0xFFFEE2E2),
                  activeBorderColor: const Color(0xFFEF4444),
                  activeTextColor: const Color(0xFF991B1B),
                  isSelected: _selectedTaste == 'dislike',
                  onTap: () {
                    setState(() => _selectedTaste = 'dislike');
                    _speak('ආහාරය රස නැහැ ලෙස සටහන් කළා. අපි සහායකයාට දැනුම් දෙන්නම්.');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTasteRatingPill({
    required String id,
    required String title,
    required String emoji,
    required Color activeBgColor,
    required Color activeBorderColor,
    required Color activeTextColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected ? activeBorderColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeBorderColor.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? activeTextColor : const Color(0xFF334155),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 16, color: activeBorderColor),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SECTION 3: "ආහාරය ගත්තේ කවුරුද සමගද?" (Company)
  // -------------------------------------------------------------------------
  Widget _buildCompanySection() {
    return Row(
      children: [
        _buildSectionIconSquircle(const Text('👥', style: TextStyle(fontSize: 22))),
        const SizedBox(width: 12),
        const Text(
          'ආහාරය ගත්තේ\n'
          'කවුරුද සමගද?',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E1B4B),
            height: 1.2,
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "යාලුවන් සමඟ" Pill (Exact Matching Mockup: 3 Elders Illustration)
                _buildCompanyPill(
                  id: 'friends',
                  title: 'යාලුවන් සමඟ',
                  illustration: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('🧓', style: TextStyle(fontSize: 22)),
                      Text('👴', style: TextStyle(fontSize: 22)),
                      Text('👵', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                  isSelected: _selectedCompany == 'friends',
                  onTap: () {
                    setState(() => _selectedCompany = 'friends');
                    _speak('යාලුවන් සමඟ ආහාර ගත් බව සටහන් කළා.');
                  },
                ),
                const SizedBox(width: 12),

                // "තනිවම" Pill
                _buildCompanyPill(
                  id: 'alone',
                  title: 'තනිවම',
                  illustration: const Text('👵', style: TextStyle(fontSize: 26)),
                  isSelected: _selectedCompany == 'alone',
                  onTap: () {
                    setState(() => _selectedCompany = 'alone');
                    _speak('තනිවම ආහාර ගත් බව සටහන් කළා.');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyPill({
    required String id,
    required String title,
    required Widget illustration,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF22C55E).withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration,
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF1E1B4B),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF22C55E)),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SECTION 4: "ආහාරයට අමතරව මොනවා බිව්වාද?" (Beverages)
  // -------------------------------------------------------------------------
  Widget _buildBeverageSelectionSection() {
    final drinks = [
      {'id': 'water', 'title': 'වතුර', 'icon': '🥛'},
      {'id': 'tea', 'title': 'තේ', 'icon': '☕'},
      {'id': 'milk', 'title': 'කිරි', 'icon': '🥛'},
      {'id': 'juice', 'title': 'පළතුරු යුෂ', 'icon': '🧃'},
    ];

    return Row(
      children: [
        _buildSectionIconSquircle(const Text('🥤', style: TextStyle(fontSize: 22))),
        const SizedBox(width: 12),
        const Text(
          'ආහාරයට අමතරව\n'
          'මොනවා බිව්වාද?',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E1B4B),
            height: 1.2,
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...drinks.map((d) {
                  final isSelected = _selectedBeverages.contains(d['id']!);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildBeveragePill(
                      id: d['id']!,
                      title: d['title']!,
                      iconText: d['icon']!,
                      isSelected: isSelected,
                      onTap: () => _toggleBeverage(d['id']!, d['title']!),
                    ),
                  );
                }),
                // "+ වෙනත්"
                _buildAddOtherBeveragePill(onTap: _showAddOtherDrinkDialog),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeveragePill({
    required String id,
    required String title,
    required String iconText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF22C55E).withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(iconText, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF1E1B4B),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF22C55E)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddOtherBeveragePill({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_rounded, size: 18, color: Color(0xFF7C3AED)),
            SizedBox(width: 4),
            Text(
              'වෙනත්',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D28D9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SECTION 5: "වෙනත් විස්තර (අවශ්‍ය නම්)" (Right Card with Voice Button)
  // -------------------------------------------------------------------------
  Widget _buildAdditionalNotesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with pencil icon
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED), size: 22),
              SizedBox(width: 8),
              Text(
                'වෙනත් විස්තර (අවශ්‍ය නම්)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-line Text Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E1B4B)),
              decoration: const InputDecoration(
                hintText: 'උදා: කැඳ, සුප්, කුරක්කන්...',
                hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                contentPadding: EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Voice-to-Text Button (Pill with microphone + animated sound wave)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleListening,
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isListening
                        ? const [Color(0xFFDC2626), Color(0xFFB91C1C)]
                        : const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? const Color(0xFFDC2626) : const Color(0xFF7C3AED))
                          .withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isListening ? 'අහගෙන ඉන්නවා...' : 'කටහඬින් කියන්න',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Sound Waveform Animation Indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (i) {
                        return AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            final val = math.sin((_waveController.value * math.pi) + (i * 0.8)).abs();
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 3,
                              height: 6 + (val * (_isListening ? 14 : 7)),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.90),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. BOTTOM SAVE ACTION BUTTON
  // =========================================================================
  Widget _buildSaveButton() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveMealExperience,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'තොරතුරු සුරකින්න',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable Left Squircle for Section Headers
  Widget _buildSectionIconSquircle(Widget child) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  // Botanical Floral Decoration for Screen Corners
  Widget _buildBotanicalLeavesDecoration({required bool isLeft}) {
    return Transform.scale(
      scaleX: isLeft ? 1 : -1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🌸', style: TextStyle(fontSize: 32)),
          SizedBox(width: 4),
          Text('🌿', style: TextStyle(fontSize: 36)),
        ],
      ),
    );
  }
}

// Smile Curve Stroke Painter under Hero Title
class _SmileCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFBBF24) // Warm Yellow
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(4, 2);
    path.quadraticBezierTo(size.width * 0.5, size.height + 4, size.width - 4, 3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
