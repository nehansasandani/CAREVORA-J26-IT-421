import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

/// Elder-friendly, high-contrast On-Screen Sinhala Virtual Keyboard.
/// Works seamlessly on Web, Desktop & Tablet touchscreens.
class SinhalaVirtualKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClose;

  const SinhalaVirtualKeyboard({
    super.key,
    required this.controller,
    required this.onTextChanged,
    required this.onClose,
  });

  @override
  State<SinhalaVirtualKeyboard> createState() => _SinhalaVirtualKeyboardState();
}

class _SinhalaVirtualKeyboardState extends State<SinhalaVirtualKeyboard> {
  bool _showNumbers = false;

  static const List<String> _pillamKeys = [
    '්',
    'ා',
    'ැ',
    'ෑ',
    'ි',
    'ී',
    'ු',
    'ූ',
    'ෙ',
    'ේ',
    'ො',
    'ෝ',
    'ං',
    '්‍ර',
  ];

  static const List<String> _vowelKeys = [
    'අ',
    'ආ',
    'ඇ',
    'ඉ',
    'ඊ',
    'උ',
    'ඌ',
    'එ',
    'ඒ',
    'ඔ',
    'ඕ',
  ];

  static const List<String> _consonantRow1 = [
    'ක',
    'ග',
    'ච',
    'ජ',
    'ට',
    'ඩ',
    'ණ',
    'ත',
    'ද',
    'න',
    'ඳ',
    'ඟ',
  ];

  static const List<String> _consonantRow2 = [
    'ප',
    'බ',
    'ම',
    'ය',
    'ර',
    'ල',
    'ළ',
    'ව',
    'ස',
    'ශ',
    'ෂ',
    'හ',
  ];

  static const List<String> _numberKeys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
  ];

  void _insertText(String insertion) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final start =
        (sel.isValid && sel.start >= 0 && sel.start <= text.length)
            ? sel.start
            : text.length;
    final end =
        (sel.isValid && sel.end >= start && sel.end <= text.length)
            ? sel.end
            : start;

    final updated = text.replaceRange(start, end, insertion);
    final newOffset = start + insertion.length;
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.onTextChanged(updated);
  }

  void _backspace() {
    final text = widget.controller.text;
    if (text.isEmpty) return;

    final sel = widget.controller.selection;
    final start =
        (sel.isValid && sel.start >= 0 && sel.start <= text.length)
            ? sel.start
            : text.length;
    final end =
        (sel.isValid && sel.end >= start && sel.end <= text.length)
            ? sel.end
            : start;

    String updated;
    int newOffset;
    if (start != end) {
      updated = text.replaceRange(start, end, '');
      newOffset = start;
    } else if (start > 0) {
      // Handle ZWJ sequences like '්‍ර' cleanly
      int removeCount = 1;
      if (start >= 3 && text.codeUnitAt(start - 2) == 0x200D) {
        removeCount = 3;
      }
      final cutStart = (start - removeCount).clamp(0, text.length);
      updated = text.replaceRange(cutStart, start, '');
      newOffset = cutStart;
    } else {
      return;
    }

    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.onTextChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAF7FF), Color(0xFFF3ECFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8B4FE), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          Row(
            children: [
              const Icon(
                LucideIcons.keyboard,
                size: 16,
                color: Color(0xFF6C3FC5),
              ),
              const SizedBox(width: 7),
              const Text(
                'සිංහල යතුරුපුවරුව',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4C1D95),
                ),
              ),
              const Spacer(),
              _buildSmallHeaderAction(
                label: _showNumbers ? 'අකුරු' : '123 අංක',
                active: _showNumbers,
                onTap: () => setState(() => _showNumbers = !_showNumbers),
              ),
              const SizedBox(width: 6),
              _buildSmallHeaderAction(
                label: 'වසන්න ✕',
                active: false,
                onTap: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 9),

          if (_showNumbers) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _numberKeys
                  .map((k) => _buildKey(k, minWidth: 48, isAccent: false))
                  .toList(),
            ),
          ] else ...[
            // Row 1: Pillam (Vowel Modifiers)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: _pillamKeys
                  .map((k) => _buildKey(k, minWidth: 38, isPillam: true))
                  .toList(),
            ),
            const SizedBox(height: 7),

            // Row 2: Vowels
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: _vowelKeys
                  .map((k) => _buildKey(k, minWidth: 42, isVowel: true))
                  .toList(),
            ),
            const SizedBox(height: 7),

            // Row 3: Consonants 1
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: _consonantRow1
                  .map((k) => _buildKey(k, minWidth: 42))
                  .toList(),
            ),
            const SizedBox(height: 6),

            // Row 4: Consonants 2
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: _consonantRow2
                  .map((k) => _buildKey(k, minWidth: 42))
                  .toList(),
            ),
          ],

          const SizedBox(height: 8),

          // Bottom Control Bar: Comma, Space, Backspace
          Row(
            children: [
              _buildKey(',', minWidth: 44),
              const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => _insertText(' '),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: const Color(0xFFD8B4FE),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'හිස්තැන (Space)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: _backspace,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFFECDD3),
                        width: 1.2,
                      ),
                    ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.backspace_outlined,
                            size: 16,
                            color: Color(0xFFE11D48),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'මකන්න',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(
    String label, {
    double minWidth = 40,
    bool isPillam = false,
    bool isVowel = false,
    bool isAccent = false,
  }) {
    final Color bg = isPillam
        ? const Color(0xFFECFEFF)
        : isVowel
            ? const Color(0xFFEDE9FE)
            : Colors.white;
    final Color border = isPillam
        ? const Color(0xFF67E8F9)
        : isVowel
            ? const Color(0xFFC4B5FD)
            : const Color(0xFFE2D9F9);
    final Color fg = isPillam
        ? const Color(0xFF0F766E)
        : isVowel
            ? const Color(0xFF5B21B6)
            : AppColors.navy;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _insertText(label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 39),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallHeaderAction({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? const Color(0xFF6C3FC5) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0xFF6C3FC5) : const Color(0xFFDDD6FE),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF5B21B6),
            ),
          ),
        ),
      ),
    );
  }
}
