import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';

enum UserRole {
  admin,
  doctor,
  caregiver,
  elder,
}

class AuthState {
  final bool isAuthenticated;
  final String? email;
  final String? userName;
  final UserRole role;
  final bool isLoading;
  final String? errorMessage;
  final int failedAttempts;
  final int lockoutSecondsRemaining;
  final String? infoMessage;
  final String? token;
  final int? elderHomeId;
  final String? elderHomeName;
  final int? residentId;
  final int? caregiverId;
  final String? avatarUrl;

  const AuthState({
    this.isAuthenticated = false,
    this.email,
    this.userName,
    this.role = UserRole.caregiver,
    this.isLoading = false,
    this.errorMessage,
    this.failedAttempts = 0,
    this.lockoutSecondsRemaining = 0,
    this.infoMessage,
    this.token,
    this.elderHomeId,
    this.elderHomeName,
    this.residentId,
    this.caregiverId,
    this.avatarUrl,
  });

  bool get isLockedOut => lockoutSecondsRemaining > 0;
  bool get isAdmin => role == UserRole.admin;
  bool get isDoctor => role == UserRole.doctor;
  bool get isCaregiver => role == UserRole.caregiver;
  bool get isElder => role == UserRole.elder;

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    String? userName,
    UserRole? role,
    bool? isLoading,
    String? errorMessage,
    int? failedAttempts,
    int? lockoutSecondsRemaining,
    String? infoMessage,
    String? token,
    int? elderHomeId,
    String? elderHomeName,
    int? residentId,
    int? caregiverId,
    String? avatarUrl,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutSecondsRemaining:
          lockoutSecondsRemaining ?? this.lockoutSecondsRemaining,
      infoMessage: infoMessage,
      token: token ?? this.token,
      elderHomeId: elderHomeId ?? this.elderHomeId,
      elderHomeName: elderHomeName ?? this.elderHomeName,
      residentId: residentId ?? this.residentId,
      caregiverId: caregiverId ?? this.caregiverId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class AuthNotifier extends ChangeNotifier {
  AuthState _state = const AuthState();
  AuthState get state => _state;
  Timer? _lockoutTimer;

  static String get baseUrl => AppConfig.backendBaseUrl;

  AuthNotifier() {
    _init();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuth = prefs.getBool('carevora_auth') ?? false;
    final email = prefs.getString('carevora_email') ?? (isAuth ? 'david.silva@carevora.com' : null);
    final roleStr = prefs.getString('carevora_role') ?? 'caregiver';
    final userName = prefs.getString('carevora_user_name') ?? (isAuth ? 'David Silva' : null);
    final elderHomeId = prefs.getInt('carevora_elder_home_id');
    final elderHomeName = prefs.getString('carevora_elder_home_name');
    final residentId = prefs.getInt('carevora_resident_id');
    final caregiverId = prefs.getInt('carevora_caregiver_id');
    final avatarUrl = prefs.getString('carevora_avatar_url');
    final token = prefs.getString('carevora_token');

    UserRole role = UserRole.caregiver;
    if (roleStr == 'admin') {
      role = UserRole.admin;
    } else if (roleStr == 'doctor') {
      role = UserRole.doctor;
    } else if (roleStr == 'elder' || roleStr == 'resident') {
      role = UserRole.elder;
    }

    _state = AuthState(
      isAuthenticated: isAuth,
      email: email,
      userName: userName,
      role: role,
      elderHomeId: elderHomeId,
      elderHomeName: elderHomeName,
      residentId: residentId,
      caregiverId: caregiverId,
      avatarUrl: avatarUrl,
      token: token,
    );
    notifyListeners();

    if (isAuth && token != null && token.isNotEmpty) {
      _refreshCurrentUserProfile(token);
    }
  }

  Future<void> _refreshCurrentUserProfile(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];
        if (data != null) {
          final avatarUrl = data['avatarUrl'] as String?;
          final name = data['name'] as String?;
          final elderHomeId = data['elderHomeId'] as int?;
          final elderHomeName = data['elderHomeName'] as String?;
          final residentId = data['residentId'] as int?;
          final caregiverId = data['caregiverId'] as int?;

          final prefs = await SharedPreferences.getInstance();
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            await prefs.setString('carevora_avatar_url', avatarUrl);
          }

          _state = _state.copyWith(
            userName: name ?? _state.userName,
            elderHomeId: elderHomeId ?? _state.elderHomeId,
            elderHomeName: elderHomeName ?? _state.elderHomeName,
            residentId: residentId ?? _state.residentId,
            caregiverId: caregiverId ?? _state.caregiverId,
            avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : _state.avatarUrl,
          );
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void setInfoMessage(String? message) {
    _state = _state.copyWith(infoMessage: message);
    notifyListeners();
  }

  void clearErrorMessage() {
    if (_state.errorMessage != null) {
      _state = _state.copyWith(errorMessage: null);
      notifyListeners();
    }
  }

  UserRole _mapRoleString(String? roleStr) {
    if (roleStr == null) return UserRole.caregiver;
    final r = roleStr.toUpperCase();
    if (r.contains('DOCTOR')) return UserRole.doctor;
    if (r.contains('ADMIN')) return UserRole.admin;
    if (r.contains('ELDER') || r.contains('RESIDENT')) return UserRole.elder;
    return UserRole.caregiver;
  }

  Future<bool> login(String email, String password, bool rememberMe) async {
    if (_state.isLockedOut) return false;

    _state = _state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();

    // 1. Attempt Live Backend API Login
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': normalizedEmail,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];
        if (data != null) {
          final token = data['token'] as String?;
          final name = data['name'] as String? ?? 'User';
          final roleString = data['role'] as String?;
          final role = _mapRoleString(roleString);
          final elderHomeId = data['elderHomeId'] as int?;
          final elderHomeName = data['elderHomeName'] as String?;
          final residentId = data['residentId'] as int?;
          final caregiverId = data['caregiverId'] as int?;
          final avatarUrl = data['avatarUrl'] as String?;

          final prefs = await SharedPreferences.getInstance();
          await _resetCollaborativeGameSession(
            prefs: prefs,
            cancelBackend: false,
          );
          if (rememberMe) {
            await prefs.setBool('carevora_auth', true);
            await prefs.setString('carevora_email', normalizedEmail);
            await prefs.setString('carevora_user_name', name);
            await prefs.setString('carevora_role', role.name);
            if (token != null) await prefs.setString('carevora_token', token);
            if (elderHomeId != null) await prefs.setInt('carevora_elder_home_id', elderHomeId);
            if (elderHomeName != null) await prefs.setString('carevora_elder_home_name', elderHomeName);
            if (residentId != null) await prefs.setInt('carevora_resident_id', residentId);
            if (caregiverId != null) await prefs.setInt('carevora_caregiver_id', caregiverId);
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              await prefs.setString('carevora_avatar_url', avatarUrl);
            } else {
              await prefs.remove('carevora_avatar_url');
            }
          }

          _state = _state.copyWith(
            isAuthenticated: true,
            email: normalizedEmail,
            userName: name,
            role: role,
            token: token,
            elderHomeId: elderHomeId,
            elderHomeName: elderHomeName,
            residentId: residentId,
            caregiverId: caregiverId,
            avatarUrl: avatarUrl,
            isLoading: false,
            failedAttempts: 0,
          );
          notifyListeners();
          return true;
        }
      }
    } catch (_) {
      // Backend request error or timeout; check fallback credentials
    }

    // 2. Seamless Local Fallback Credentials
    AuthState? fallbackState;
    if (normalizedEmail == 'david.silva@carevora.com' && (password == 'carevora123' || password == 'demo1234')) {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'david.silva@carevora.com',
        userName: 'David Silva',
        role: UserRole.caregiver,
        elderHomeId: 2,
        elderHomeName: 'Golden Sunset Eldercare',
        avatarUrl: 'assets/images/landing/testimonial_2.jpg',
      );
    } else if ((normalizedEmail == 'ps@gmail.com' || normalizedEmail == 'pasidi.sarangi@carevora.com' || normalizedEmail == 'pasidi@carevora.com') &&
        (password == '123456' || password == 'carevora123' || password == 'demo1234')) {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'ps@gmail.com',
        userName: 'Pasidi Sarangi',
        role: UserRole.caregiver,
        elderHomeId: 3,
        elderHomeName: 'Serenity Elder Home',
        avatarUrl: 'assets/images/landing/caregivers_team.jpg',
      );
    } else if (normalizedEmail == 'eleanor.vance@carevora.com' && (password == 'carevora_admin' || password == 'carevora123')) {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'eleanor.vance@carevora.com',
        userName: 'Eleanor Vance',
        role: UserRole.caregiver,
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        avatarUrl: 'assets/images/landing/caregivers_team.jpg',
      );
    } else if (normalizedEmail == 'seetha@carevora.com' && password == 'demo1234') {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'seetha@carevora.com',
        userName: 'Seetha N.',
        role: UserRole.caregiver,
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        avatarUrl: 'assets/images/landing/caregivers_team.jpg',
      );
    } else if ((normalizedEmail == 'dr.reed@carevora.com' || normalizedEmail == 'doctor@carevora.com' || normalizedEmail == 'nimal@carevora.com') &&
        (password == 'doctor123' || password == 'demo1234')) {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'dr.reed@carevora.com',
        userName: 'Dr. Samantha Reed',
        role: UserRole.doctor,
        avatarUrl: 'assets/images/landing/hero_caregiver_hug.jpg',
      );
    } else if ((normalizedEmail == 'sarah.jenkins@carevora.com') && (password == 'carevora123' || password == 'demo1234')) {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'sarah.jenkins@carevora.com',
        userName: 'Sarah Jenkins',
        role: UserRole.elder,
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        residentId: 1,
        avatarUrl: 'assets/images/landing/testimonial_1.jpg',
      );
    } else if ((normalizedEmail == 'margaret.c@carevora.com' || normalizedEmail == 'robert.h@carevora.com') && password == 'carevora123') {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'margaret.c@carevora.com',
        userName: 'Margaret Chen',
        role: UserRole.elder,
        elderHomeId: 2,
        elderHomeName: 'Golden Sunset Eldercare',
        residentId: 3,
        avatarUrl: 'assets/images/landing/testimonial_3.jpg',
      );
    } else if ((normalizedEmail == 'admin@carevora.com' || normalizedEmail == 'admin') && password == 'admin123') {
      fallbackState = const AuthState(
        isAuthenticated: true,
        email: 'admin@carevora.com',
        userName: 'System Admin',
        role: UserRole.admin,
      );
    }

    if (fallbackState != null) {
      final prefs = await SharedPreferences.getInstance();
      await _resetCollaborativeGameSession(
        prefs: prefs,
        cancelBackend: false,
      );
      if (rememberMe) {
        await prefs.setBool('carevora_auth', true);
        await prefs.setString('carevora_email', fallbackState.email!);
        await prefs.setString('carevora_user_name', fallbackState.userName!);
        await prefs.setString('carevora_role', fallbackState.role.name);
        if (fallbackState.elderHomeId != null) {
          await prefs.setInt('carevora_elder_home_id', fallbackState.elderHomeId!);
        }
        if (fallbackState.elderHomeName != null) {
          await prefs.setString('carevora_elder_home_name', fallbackState.elderHomeName!);
        }
        if (fallbackState.residentId != null) {
          await prefs.setInt('carevora_resident_id', fallbackState.residentId!);
        }
        if (fallbackState.caregiverId != null) {
          await prefs.setInt('carevora_caregiver_id', fallbackState.caregiverId!);
        }
        if (fallbackState.avatarUrl != null) {
          await prefs.setString('carevora_avatar_url', fallbackState.avatarUrl!);
        }
      }
      _state = fallbackState.copyWith(
        isLoading: false,
        failedAttempts: 0,
      );
      notifyListeners();
      return true;
    }

    final newFailedAttempts = _state.failedAttempts + 1;
    int lockoutTime = 0;

    if (newFailedAttempts >= 5) {
      lockoutTime = 30;
      _startLockoutCountdown(30);
    }

    _state = _state.copyWith(
      isLoading: false,
      failedAttempts: newFailedAttempts,
      lockoutSecondsRemaining: lockoutTime,
      errorMessage: newFailedAttempts >= 5
          ? 'Account temporarily locked due to multiple failed attempts.'
          : 'Invalid credentials. Please verify your email and password.',
    );
    notifyListeners();
    return false;
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _state.lockoutSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        _state = _state.copyWith(
          lockoutSecondsRemaining: 0,
          failedAttempts: 0,
          errorMessage: null,
        );
      } else {
        _state = _state.copyWith(lockoutSecondsRemaining: remaining);
      }
      notifyListeners();
    });
  }

  Future<void> _resetCollaborativeGameSession({
    required SharedPreferences prefs,
    required bool cancelBackend,
    String? userName,
    String? token,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.remove('carevora_picnic_game_invites_v1');
    await prefs.remove('carevora_picnic_dismissed_invites_v1');
    await prefs.setInt('carevora_collab_session_epoch_ms', nowMs);

    if (!cancelBackend) return;
    final cleanUser = (userName ?? '').trim().toLowerCase();
    if (cleanUser.isEmpty) return;

    // Best-effort cleanup of this user's old backend invites & live rooms on logout
    unawaited(() async {
      try {
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        };
        final getUri = Uri.parse('$baseUrl/api/memory-games/invites');
        final res = await http
            .get(getUri, headers: headers)
            .timeout(const Duration(seconds: 2));
        if (res.statusCode != 200) return;
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] as List?;
        if (data == null) return;

        for (final item in data) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final id = map['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          final recordType =
              (map['recordType']?.toString() ?? '').toUpperCase();
          if (recordType == 'LIVE_ROOM_STATE') {
            final participants = (map['participants'] as List?)
                    ?.map((e) => e.toString().trim().toLowerCase())
                    .toList() ??
                const <String>[];
            final stage = (map['stage']?.toString() ?? '');
            if (participants.contains(cleanUser) && stage != 'ended') {
              await http
                  .post(
                    getUri,
                    headers: headers,
                    body: jsonEncode({...map, 'stage': 'ended'}),
                  )
                  .timeout(const Duration(seconds: 2));
            }
          } else {
            final sender =
                (map['senderName']?.toString() ?? '').trim().toLowerCase();
            final target =
                (map['targetName']?.toString() ?? '').trim().toLowerCase();
            final status = (map['status']?.toString() ?? '').toUpperCase();
            if ((sender == cleanUser || target == cleanUser) &&
                (status == 'PENDING' || status == 'ACCEPTED')) {
              final respUri =
                  Uri.parse('$baseUrl/api/memory-games/invites/$id/respond');
              await http
                  .post(
                    respUri,
                    headers: headers,
                    body: jsonEncode({'status': 'CANCELLED'}),
                  )
                  .timeout(const Duration(seconds: 2));
            }
          }
        }
      } catch (_) {}
    }());
  }

  Future<void> logout() async {
    final prevUser = _state.userName;
    final prevToken = _state.token;
    final prefs = await SharedPreferences.getInstance();
    await _resetCollaborativeGameSession(
      prefs: prefs,
      cancelBackend: true,
      userName: prevUser,
      token: prevToken,
    );
    await prefs.remove('carevora_auth');
    await prefs.remove('carevora_role');
    await prefs.remove('carevora_token');
    await prefs.remove('carevora_email');
    await prefs.remove('carevora_user_name');
    await prefs.remove('carevora_elder_home_id');
    await prefs.remove('carevora_elder_home_name');
    await prefs.remove('carevora_resident_id');
    await prefs.remove('carevora_caregiver_id');
    await prefs.remove('carevora_avatar_url');
    _state = const AuthState(isAuthenticated: false);
    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
