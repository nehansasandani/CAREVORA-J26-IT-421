class SinhalaTypingHelper {
  SinhalaTypingHelper._();

  static final RegExp _latinWordRegex = RegExp(r'^[A-Za-z]+$');
  static final RegExp _completedWordRegex = RegExp(r'([A-Za-z]+)([\s,.;!?]+)');
  static final RegExp _trailingWordRegex = RegExp(r'([A-Za-z]+)$');

  /// Common Sri Lankan Sinhala words & everyday vocabulary for exact Singlish spelling.
  static const Map<String, String> _commonWords = {
    // Days of week
    'sanduda': 'සඳුදා',
    'saduda': 'සඳුදා',
    'handuda': 'සඳුදා',
    'angaharuwada': 'අඟහරුවාදා',
    'agaharuwada': 'අඟහරුවාදා',
    'angaharu': 'අඟහරුවාදා',
    'badada': 'බදාදා',
    'badaada': 'බදාදා',
    'brahaspathinda': 'බ්‍රහස්පතින්දා',
    'brahaspatinda': 'බ්‍රහස්පතින්දා',
    'brahaspathi': 'බ්‍රහස්පතින්දා',
    'sikurada': 'සිකුරාදා',
    'sikuraada': 'සිකුරාදා',
    'senasurada': 'සෙනසුරාදා',
    'senasuraada': 'සෙනසුරාදා',
    'irida': 'ඉරිදා',
    'iriida': 'ඉරිදා',

    // Common assessment & everyday words
    'ira': 'ඉර',
    'hiru': 'හිරු',
    'potha': 'පොත',
    'poth': 'පොත්',
    'gasa': 'ගස',
    'gaha': 'ගහ',
    'ow': 'ඔව්',
    'ou': 'ඔව්',
    'owu': 'ඔව්',
    'ov': 'ඔව්',
    'nae': 'නැහැ',
    'na': 'නෑ',
    'naha': 'නැහැ',
    'natha': 'නැත',
    'ne': 'නෑ',
    'oralosuwa': 'ඔරලෝසුව',
    'oralosu': 'ඔරලෝසු',
    'athoralosuwa': 'අත්ඔරලෝසුව',
    'bithioralosuwa': 'බිත්ති ඔරලෝසුව',
    'palathuru': 'පලතුරු',
    'palathuruda': 'පලතුරුද',
    'dekama': 'දෙකම',
    'apple': 'ඇපල්',
    'epal': 'ඇපල්',
    'dodam': 'දොඩම්',
    'welawa': 'වේලාව',
    'welaawa': 'වේලාව',
    'ada': 'අද',
    'heta': 'හෙට',
    'iye': 'ඊයේ',
    'awurudda': 'අවුරුද්ද',
    'dawasa': 'දවස',
    'dawas': 'දවස්',

    // Numbers
    'eka': 'එක',
    'deka': 'දෙක',
    'thuna': 'තුන',
    'hathara': 'හතර',
    'paha': 'පහ',
    'haya': 'හය',
    'hatha': 'හත',
    'ata': 'අට',
    'nawaya': 'නවය',
    'dahaya': 'දහය',
    'binduwa': 'බිංදුව',

    // Common everyday words
    'mama': 'මම',
    'oba': 'ඔබ',
    'api': 'අපි',
    'honda': 'හොඳ',
    'hondai': 'හොඳයි',
    'hodai': 'හොඳයි',
    'sathutui': 'සතුටුයි',
    'sathuta': 'සතුට',
    'sthuthi': 'ස්තූතියි',
    'sthuthiyi': 'ස්තූතියි',
    'ayubowan': 'ආයුබෝවන්',
    'suba': 'සුබ',
    'udasanak': 'උදෑසනක්',
    'gedara': 'ගෙදර',
    'amma': 'අම්මා',
    'thaththa': 'තාත්තා',
    'mal': 'මල්',
    'wathura': 'වතුර',
    'bima': 'බීම',
    'kema': 'කෑම',
    'kaema': 'කෑම',
    'the': 'තේ',
    'gama': 'ගම',
    'rata': 'රට',
    'lanka': 'ලංකා',
    'sri': 'ශ්‍රී',
    'hari': 'හරි',
    'owwa': 'ඔව්',
  };

  /// Converts a single Singlish word into Sinhala Unicode.
  static String transliterateWord(String rawWord) {
    final trimmed = rawWord.trim();
    if (trimmed.isEmpty || !_latinWordRegex.hasMatch(trimmed)) {
      return rawWord;
    }
    final lower = trimmed.toLowerCase();
    if (_commonWords.containsKey(lower)) {
      return _commonWords[lower]!;
    }
    return _phoneticTransliterate(lower);
  }

  /// Converts all Latin words that are already followed by whitespace or punctuation.
  /// Leaves the currently-being-typed trailing Latin word intact so multi-letter
  /// Singlish sequences (like "th", "aa", "nd") compose smoothly without glitching.
  static String convertCompletedWords(String text) {
    if (text.isEmpty) return text;
    return text.replaceAllMapped(_completedWordRegex, (m) {
      final latin = m.group(1)!;
      final sep = m.group(2)!;
      return '${transliterateWord(latin)}$sep';
    });
  }

  /// Converts every Latin word in [text], including any trailing active word.
  static String convertAllLatinWords(String text) {
    if (text.isEmpty) return text;
    final step1 = convertCompletedWords(text);
    return step1.replaceAllMapped(_trailingWordRegex, (m) {
      return transliterateWord(m.group(1)!);
    });
  }

  /// Returns a live preview for the trailing active Singlish word (if any).
  static ({String rawWord, String sinhala})? previewActiveWord(String text) {
    if (text.isEmpty) return null;
    final match = _trailingWordRegex.firstMatch(text);
    if (match == null) return null;
    final word = match.group(1)!;
    if (word.isEmpty) return null;
    return (rawWord: word, sinhala: transliterateWord(word));
  }

  static bool _isVowel(String ch) =>
      ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u';

  static String _phoneticTransliterate(String word) {
    final buf = StringBuffer();
    int i = 0;
    final n = word.length;

    while (i < n) {
      if (_isVowel(word[i])) {
        final v = _matchIndependentVowel(word, i);
        buf.write(v.si);
        i += v.len;
        continue;
      }

      // Nasal clusters: ng / nk / nj / ndh
      if (word[i] == 'n' && i + 1 < n) {
        final next = word[i + 1];
        if (next == 'g') {
          if (i + 2 == n) {
            buf.write('ං');
            i += 2;
            continue;
          }
          if (i + 2 < n && _isVowel(word[i + 2])) {
            buf.write('ංග');
            i += 2;
            final dep = _matchDependentVowel(word, i);
            buf.write(dep.si);
            i += dep.len;
            continue;
          }
        } else if ((next == 'k' || next == 'j') && i + 2 < n) {
          buf.write('ං');
          i += 1;
          continue;
        }
      }

      final c = _matchConsonant(word, i);
      if (c.len == 0) {
        buf.write(word[i]);
        i++;
        continue;
      }

      String cons = c.si;
      i += c.len;

      // Rakaranshaya: C + r + vowel
      if (i + 1 < n && word[i] == 'r' && c.raw != 'r' && _isVowel(word[i + 1])) {
        cons = '$cons\u0DCA\u200D\u0DBB';
        i += 1;
      }
      // Yansaya: C + y + vowel
      else if (i + 1 < n &&
          word[i] == 'y' &&
          c.raw != 'y' &&
          c.raw != 'r' &&
          _isVowel(word[i + 1])) {
        cons = '$cons\u0DCA\u200D\u0DBA';
        i += 1;
      }

      if (i < n && _isVowel(word[i])) {
        final dep = _matchDependentVowel(word, i);
        buf.write(cons);
        buf.write(dep.si);
        i += dep.len;
      } else {
        buf.write(cons);
        buf.write('\u0DCA');
      }
    }

    return buf.toString();
  }

  static _Tok _matchConsonant(String s, int i) {
    final rem = s.length - i;
    if (rem >= 3 && s.substring(i, i + 3) == 'ksh') {
      return const _Tok('ක්ෂ', 3, 'ksh');
    }
    if (rem >= 2) {
      switch (s.substring(i, i + 2)) {
        case 'ch':
          return const _Tok('ච', 2, 'ch');
        case 'sh':
          return const _Tok('ශ', 2, 'sh');
        case 'th':
          return const _Tok('ත', 2, 'th');
        case 'dh':
          return const _Tok('ද', 2, 'dh');
        case 'bh':
          return const _Tok('භ', 2, 'bh');
        case 'ph':
          return const _Tok('ෆ', 2, 'ph');
        case 'kh':
          return const _Tok('ඛ', 2, 'kh');
        case 'gh':
          return const _Tok('ඝ', 2, 'gh');
        case 'gn':
          return const _Tok('ඥ', 2, 'gn');
        case 'ck':
          return const _Tok('ක', 2, 'ck');
      }
    }

    switch (s[i]) {
      case 'k':
      case 'q':
      case 'c':
        return _Tok('ක', 1, s[i]);
      case 'g':
        return const _Tok('ග', 1, 'g');
      case 'j':
        return const _Tok('ජ', 1, 'j');
      case 't':
        return const _Tok('ට', 1, 't');
      case 'd':
        return const _Tok('ද', 1, 'd');
      case 'n':
        return const _Tok('න', 1, 'n');
      case 'p':
        return const _Tok('ප', 1, 'p');
      case 'f':
        return const _Tok('ෆ', 1, 'f');
      case 'b':
        return const _Tok('බ', 1, 'b');
      case 'm':
        return const _Tok('ම', 1, 'm');
      case 'y':
        return const _Tok('ය', 1, 'y');
      case 'r':
        return const _Tok('ර', 1, 'r');
      case 'l':
        return const _Tok('ල', 1, 'l');
      case 'v':
      case 'w':
        return _Tok('ව', 1, s[i]);
      case 's':
      case 'z':
        return _Tok('ස', 1, s[i]);
      case 'h':
        return const _Tok('හ', 1, 'h');
      default:
        return const _Tok('', 0, '');
    }
  }

  static _Tok _matchIndependentVowel(String s, int i) {
    if (i + 1 < s.length) {
      switch (s.substring(i, i + 2)) {
        case 'aa':
          return const _Tok('ආ', 2, 'aa');
        case 'ae':
          return const _Tok('ඇ', 2, 'ae');
        case 'ai':
          return const _Tok('අයි', 2, 'ai');
        case 'au':
          return const _Tok('අවු', 2, 'au');
        case 'ee':
        case 'ii':
          return _Tok('ඊ', 2, s.substring(i, i + 2));
        case 'oo':
        case 'uu':
          return _Tok('ඌ', 2, s.substring(i, i + 2));
      }
    }
    switch (s[i]) {
      case 'a':
        return const _Tok('අ', 1, 'a');
      case 'e':
        return const _Tok('එ', 1, 'e');
      case 'i':
        return const _Tok('ඉ', 1, 'i');
      case 'o':
        return const _Tok('ඔ', 1, 'o');
      case 'u':
        return const _Tok('උ', 1, 'u');
      default:
        return const _Tok('', 0, '');
    }
  }

  static _Tok _matchDependentVowel(String s, int i) {
    if (i + 1 < s.length) {
      switch (s.substring(i, i + 2)) {
        case 'aa':
          return const _Tok('ා', 2, 'aa');
        case 'ae':
          return const _Tok('ැ', 2, 'ae');
        case 'ai':
          return const _Tok('යි', 2, 'ai');
        case 'au':
          return const _Tok('වු', 2, 'au');
        case 'ee':
        case 'ii':
          return _Tok('ී', 2, s.substring(i, i + 2));
        case 'oo':
        case 'uu':
          return _Tok('ූ', 2, s.substring(i, i + 2));
      }
    }
    switch (s[i]) {
      case 'a':
        return const _Tok('', 1, 'a');
      case 'e':
        return const _Tok('ෙ', 1, 'e');
      case 'i':
        return const _Tok('ි', 1, 'i');
      case 'o':
        return const _Tok('ො', 1, 'o');
      case 'u':
        return const _Tok('ු', 1, 'u');
      default:
        return const _Tok('', 0, '');
    }
  }
}

class _Tok {
  final String si;
  final int len;
  final String raw;

  const _Tok(this.si, this.len, this.raw);
}
