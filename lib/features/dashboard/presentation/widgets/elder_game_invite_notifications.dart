import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/localization/sinhala_name_transliterator.dart';
import '../../../../core/services/app_settings_controller.dart';
import '../../../../core/theme/app_colors.dart';

/// Elder-only live game invite notification controller & overlay host.
/// Provides:
///  1. Live pending invite list + count for the top-bar Bell icon & dropdown panel
///  2. Animated floating notification card at the top-right when a friend sends an invite
class ElderInviteNotificationHost extends StatefulWidget {
  final bool enabled;
  final String? elderName;
  final int elderHomeId;
  final String? token;
  final bool isSinhala;
  final Widget Function(
    BuildContext context,
    Widget bellButton,
  ) builder;

  const ElderInviteNotificationHost({
    super.key,
    required this.enabled,
    required this.elderName,
    required this.elderHomeId,
    required this.token,
    required this.isSinhala,
    required this.builder,
  });

  @override
  State<ElderInviteNotificationHost> createState() =>
      _ElderInviteNotificationHostState();
}

class _ElderInviteNotificationHostState
    extends State<ElderInviteNotificationHost> {
  static const String _prefsInvitesKey = 'carevora_picnic_game_invites_v1';
  static const String _prefsDismissedInvitesKey =
      'carevora_picnic_dismissed_invites_v1';

  Timer? _pollTimer;
  List<Map<String, dynamic>> _pendingInvites = [];
  final Set<String> _hiddenFloatingIds = {};
  final Set<String> _locallyActedIds = {};
  bool _isDeactivated = false;
  Set<String>? _seenAcceptedInviteIds;
  bool? _hasSeededAcceptedIds;
  Map<String, dynamic>? _activeAcceptedToast;
  Timer? _acceptedToastTimer;
  List<Map<String, dynamic>>? _unreadResponseNotifications;
  Map<String, dynamic>? _liveGameStartedPrompt;
  Set<String>? _dismissedLiveRoomIds;

  int get _totalNotificationCount =>
      _pendingInvites.length + (_unreadResponseNotifications?.length ?? 0);

  @override
  void initState() {
    super.initState();
    _startPollingIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ElderInviteNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.elderName != widget.elderName ||
        oldWidget.elderHomeId != widget.elderHomeId) {
      _pollTimer?.cancel();
      _acceptedToastTimer?.cancel();
      _pendingInvites = [];
      _hiddenFloatingIds.clear();
      _locallyActedIds.clear();
      _seenAcceptedInviteIds = null;
      _hasSeededAcceptedIds = null;
      _activeAcceptedToast = null;
      _unreadResponseNotifications = null;
      _liveGameStartedPrompt = null;
      _dismissedLiveRoomIds = null;
      _startPollingIfNeeded();
    }
  }

  void _startPollingIfNeeded() {
    if (!widget.enabled) return;
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDeactivated) {
        _pollPendingInvites();
      }
    });
    if (!isTestEnv) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollPendingInvites(),
      );
    }
  }

  @override
  void deactivate() {
    _isDeactivated = true;
    _pollTimer?.cancel();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isDeactivated = false;
    _startPollingIfNeeded();
  }

  @override
  void dispose() {
    _isDeactivated = true;
    _pollTimer?.cancel();
    _acceptedToastTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollPendingInvites() async {
    if (!mounted ||
        _isDeactivated ||
        !widget.enabled ||
        !AppSettingsController.gameInvitePopupsEnabledLive) {
      if (_pendingInvites.isNotEmpty &&
          !AppSettingsController.gameInvitePopupsEnabledLive &&
          mounted) {
        setState(() {
          _pendingInvites = [];
          _activeAcceptedToast = null;
          _liveGameStartedPrompt = null;
        });
      }
      return;
    }
    final myNameLower = (widget.elderName ?? '').trim().toLowerCase();
    if (myNameLower.isEmpty) return;

    final Map<String, Map<String, dynamic>> merged = {};
    final Set<String> dismissed = {};
    int sessionEpoch = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      sessionEpoch = prefs.getInt('carevora_collab_session_epoch_ms') ?? 0;
      final disList = prefs.getStringList(_prefsDismissedInvitesKey);
      if (disList != null) dismissed.addAll(disList);

      final raw = prefs.getString(_prefsInvitesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) merged[id] = map;
          }
        }
      }
    } catch (_) {}

    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/invites',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] as List?;
        if (data != null) {
          for (final item in data) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final id = map['id']?.toString() ?? '';
              if (id.isNotEmpty) {
                // Keep local non-pending status only if backend still returns stale PENDING
                final existing = merged[id];
                final existingStatus =
                    (existing?['status']?.toString() ?? '').toUpperCase();
                final incomingStatus =
                    (map['status']?.toString() ?? '').toUpperCase();
                if (existing != null &&
                    existingStatus != 'PENDING' &&
                    existingStatus.isNotEmpty &&
                    incomingStatus == 'PENDING') {
                  continue;
                }
                merged[id] = map;
              }
            }
          }
        }
      }
    } catch (_) {}

    final List<Map<String, dynamic>> incoming = [];
    final List<Map<String, dynamic>> myRespondedSentInvites = [];
    final Map<String, int> latestAcceptedAtBySender = {};
    final dismissedRooms = _dismissedLiveRoomIds ??= <String>{};
    Map<String, dynamic>? newestLiveRoomForMe;
    int newestLiveStartedAt = -1;

    for (final inv in merged.values) {
      final id = inv['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final recordType = (inv['recordType']?.toString() ?? '').toUpperCase();
      if (recordType == 'LIVE_ROOM_STATE') {
        if (dismissedRooms.contains(id)) continue;
        final stage = (inv['stage']?.toString() ?? '');
        if (stage == 'completed' || stage == 'ended' || stage == 'lobbyInvite') {
          continue;
        }
        final startedByLower =
            (inv['startedBy']?.toString() ?? '').trim().toLowerCase();
        if (startedByLower.isEmpty || startedByLower == myNameLower) continue;
        final participants = (inv['participants'] as List?)
                ?.map((e) => e.toString().trim().toLowerCase())
                .toList() ??
            const <String>[];
        if (!participants.contains(myNameLower)) continue;
        final joinedLive = (inv['joinedLivePlayers'] as List?)
                ?.map((e) => e.toString().trim().toLowerCase())
                .toList() ??
            const <String>[];
        if (joinedLive.contains(myNameLower)) continue;
        final startedAt = int.tryParse(inv['startedAt']?.toString() ?? '') ?? 0;
        if (sessionEpoch > 0 && startedAt > 0 && startedAt < sessionEpoch) {
          continue;
        }
        if (startedAt >= newestLiveStartedAt) {
          newestLiveStartedAt = startedAt;
          newestLiveRoomForMe = inv;
        }
        continue;
      }

      final createdAtCheck =
          int.tryParse(inv['createdAt']?.toString() ?? '') ?? 0;
      if (sessionEpoch > 0 &&
          createdAtCheck > 0 &&
          createdAtCheck < sessionEpoch) {
        continue;
      }

      if (dismissed.contains(id) || _locallyActedIds.contains(id)) {
        continue;
      }
      final senderLower =
          (inv['senderName']?.toString() ?? '').trim().toLowerCase();
      final targetLower =
          (inv['targetName']?.toString() ?? '').trim().toLowerCase();
      final status = (inv['status']?.toString() ?? 'PENDING').toUpperCase();
      final createdAt = int.tryParse(inv['createdAt']?.toString() ?? '') ?? 0;
      if (targetLower == myNameLower && status == 'ACCEPTED') {
        final prev = latestAcceptedAtBySender[senderLower] ?? -1;
        if (createdAt > prev) {
          latestAcceptedAtBySender[senderLower] = createdAt;
        }
      } else if (targetLower == myNameLower && status == 'PENDING') {
        incoming.add(inv);
      } else if (senderLower == myNameLower &&
          (status == 'ACCEPTED' || status == 'DECLINED')) {
        myRespondedSentInvites.add(inv);
      }
    }

    // Deduplicate pending invites per sender and skip only older stale pending invites
    incoming.sort((a, b) {
      final ta = int.tryParse(a['createdAt']?.toString() ?? '') ?? 0;
      final tb = int.tryParse(b['createdAt']?.toString() ?? '') ?? 0;
      return tb.compareTo(ta);
    });
    final Set<String> seenPendingSenders = {};
    final List<Map<String, dynamic>> dedupedIncoming = [];
    for (final inv in incoming) {
      final senderLower =
          (inv['senderName']?.toString() ?? '').trim().toLowerCase();
      final createdAt = int.tryParse(inv['createdAt']?.toString() ?? '') ?? 0;
      final acceptedAt = latestAcceptedAtBySender[senderLower];
      if (acceptedAt != null && createdAt <= acceptedAt) {
        continue;
      }
      if (senderLower.isNotEmpty && !seenPendingSenders.add(senderLower)) {
        continue;
      }
      dedupedIncoming.add(inv);
    }

    if (!mounted || _isDeactivated) return;

    // Detect newly accepted OR declined invites
    final seenResponded = _seenAcceptedInviteIds ??= <String>{};
    final List<Map<String, dynamic>> newlyRespondedList = [];
    if (_hasSeededAcceptedIds != true) {
      for (final inv in myRespondedSentInvites) {
        final id = inv['id']?.toString() ?? '';
        final st = (inv['status']?.toString() ?? '').toUpperCase();
        if (id.isNotEmpty) seenResponded.add('${id}_$st');
      }
      _hasSeededAcceptedIds = true;
    } else {
      for (final inv in myRespondedSentInvites) {
        final id = inv['id']?.toString() ?? '';
        final st = (inv['status']?.toString() ?? '').toUpperCase();
        final key = '${id}_$st';
        if (id.isNotEmpty && !seenResponded.contains(key)) {
          seenResponded.add(key);
          newlyRespondedList.add(inv);
        }
      }
    }

    // Clean up hidden IDs that are no longer pending
    final activeIds =
        dedupedIncoming.map((e) => e['id']?.toString() ?? '').toSet();
    _hiddenFloatingIds.removeWhere((id) => !activeIds.contains(id));

    final pendingChanged = _listChanged(_pendingInvites, dedupedIncoming);
    final liveRoomChanged =
        (_liveGameStartedPrompt?['id']?.toString() ?? '') !=
            (newestLiveRoomForMe?['id']?.toString() ?? '');
    if (pendingChanged || newlyRespondedList.isNotEmpty || liveRoomChanged) {
      setState(() {
        if (pendingChanged) {
          _pendingInvites = dedupedIncoming;
        }
        _liveGameStartedPrompt = newestLiveRoomForMe;
        if (newlyRespondedList.isNotEmpty) {
          final unread = _unreadResponseNotifications ??= [];
          for (final inv in newlyRespondedList) {
            final key =
                '${inv['id']}_${(inv['status'] ?? '').toString().toUpperCase()}';
            unread.removeWhere(
              (e) =>
                  '${e['id']}_${(e['status'] ?? '').toString().toUpperCase()}' ==
                  key,
            );
            unread.insert(0, inv);
          }
          _activeAcceptedToast = newlyRespondedList.last;
        }
      });
      if (newlyRespondedList.isNotEmpty) {
        _acceptedToastTimer?.cancel();
        _acceptedToastTimer = Timer(const Duration(seconds: 6), () {
          if (mounted && !_isDeactivated) {
            setState(() {
              _activeAcceptedToast = null;
            });
          }
        });
      }
    }
  }

  bool _listChanged(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList,
  ) {
    if (oldList.length != newList.length) return true;
    for (var i = 0; i < oldList.length; i++) {
      if (oldList[i]['id']?.toString() != newList[i]['id']?.toString() ||
          oldList[i]['status']?.toString() != newList[i]['status']?.toString()) {
        return true;
      }
    }
    return false;
  }

  Future<void> _respondToInvite(
    Map<String, dynamic> invite, {
    required bool accept,
  }) async {
    final inviteId = invite['id']?.toString() ?? '';
    final newStatus = accept ? 'ACCEPTED' : 'DECLINED';
    if (inviteId.isNotEmpty) {
      _locallyActedIds.add(inviteId);
    }

    setState(() {
      _pendingInvites = _pendingInvites
          .where((e) => e['id']?.toString() != inviteId)
          .toList();
    });

    final updatedRecord = <String, dynamic>{
      ...invite,
      'status': newStatus,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsInvitesKey);
      final List<Map<String, dynamic>> current = [];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map['id']?.toString() != inviteId) {
              current.add(map);
            }
          }
        }
      }
      current.add(updatedRecord);
      await prefs.setString(_prefsInvitesKey, jsonEncode(current));
    } catch (_) {}

    if (inviteId.isNotEmpty) {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/invites/$inviteId/respond',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      try {
        await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({'status': newStatus}),
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    if (accept && mounted) {
      context.go('/dashboard/memory-games?game=collaborative');
    }
  }

  String _formatSenderName(String rawName) {
    final clean = rawName.trim().isEmpty ? 'Fellow Elder' : rawName.trim();
    if (!widget.isSinhala) return clean;
    return SinhalaNameTransliterator.toSinhala(clean, fallback: clean);
  }

  void _openElderNotificationsDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            final isSi = widget.isSinhala;
            final responses = _unreadResponseNotifications ?? const [];
            final count = _pendingInvites.length + responses.length;
            final totalItems = _pendingInvites.length + responses.length;

            return Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 72, right: 20, left: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 400,
                    constraints: const BoxConstraints(maxHeight: 480),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header bar with live total count
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF1E1B4B),
                                  Color(0xFF2563EB),
                                  Color(0xFF0D9488),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.bell,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    isSi
                                        ? 'දැනුම්දීම් ($count)'
                                        : 'Notifications ($count)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (responses.isNotEmpty) ...[
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _unreadResponseNotifications = [];
                                      });
                                      setDialogState(() {});
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFDE68A),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      isSi ? 'හිස් කරන්න' : 'Clear',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                IconButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(),
                                  icon: const Icon(
                                    LucideIcons.x,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                          if (totalItems == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 34,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      LucideIcons.bell,
                                      color: Color(0xFF2563EB),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isSi
                                        ? 'නව දැනුම්දීම් කිසිවක් නැත'
                                        : 'No new notifications',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isSi
                                        ? 'මිතුරෙකු ක්‍රීඩාවට ආරාධනා කළ විට මෙහි පෙන්වයි.'
                                        : 'Game invitations from your friends will appear here.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.all(14),
                                itemCount: totalItems,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, idx) {
                                  if (idx < _pendingInvites.length) {
                                    final inv = _pendingInvites[idx];
                                    final rawSender =
                                        (inv['senderName']?.toString() ??
                                                'Fellow Elder')
                                            .trim();
                                    final senderDisplay =
                                        _formatSenderName(rawSender);
                                    final initial = rawSender.isNotEmpty
                                        ? rawSender.substring(0, 1).toUpperCase()
                                        : 'F';

                                    return Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF0F9FF),
                                            Color(0xFFF5F3FF),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF93C5FD),
                                          width: 1.3,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 19,
                                                backgroundColor:
                                                    const Color(0xFF2563EB),
                                                child: Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 11),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isSi
                                                          ? '🧺 විනෝද චාරිකා ක්‍රීඩා ආරාධනාවක්!'
                                                          : '🧺 Picnic Memory Game Invite!',
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color:
                                                            Color(0xFF1E3A8A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      isSi
                                                          ? '$senderDisplay ඔබට හවුල් විනෝද චාරිකා මතක ක්‍රීඩාව සෙල්ලම් කිරීමට ආරාධනා කරයි!'
                                                          : '$senderDisplay invited you to play Shared Picnic Memory Chain together!',
                                                      style: const TextStyle(
                                                        fontSize: 12.8,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors.navy,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.of(dialogCtx)
                                                        .pop();
                                                    _respondToInvite(
                                                      inv,
                                                      accept: true,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    LucideIcons.check,
                                                    size: 14,
                                                  ),
                                                  label: Text(
                                                    isSi
                                                        ? 'එක්වී සෙල්ලම් කරන්න'
                                                        : 'Accept & Play',
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF10B981),
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 9,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        11,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                onPressed: () {
                                                  Navigator.of(dialogCtx).pop();
                                                  _respondToInvite(
                                                    inv,
                                                    accept: false,
                                                  );
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      const Color(0xFFDC2626),
                                                  side: const BorderSide(
                                                    color: Color(0xFFFCA5A5),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 9,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      11,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  isSi ? 'එපා' : 'Decline',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Unread response notification (Friend Accepted or Declined)
                                  final rIdx = idx - _pendingInvites.length;
                                  final resp = responses[rIdx];
                                  final st =
                                      (resp['status']?.toString() ?? 'ACCEPTED')
                                          .toUpperCase();
                                  final isDeclined = st == 'DECLINED';
                                  final rawFriend =
                                      (resp['targetName']?.toString() ??
                                              'Fellow Elder')
                                          .trim();
                                  final friendDisplay =
                                      _formatSenderName(rawFriend);
                                  final initial = rawFriend.isNotEmpty
                                      ? rawFriend.substring(0, 1).toUpperCase()
                                      : 'F';

                                  return Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: isDeclined
                                          ? const Color(0xFFFFF1F2)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDeclined
                                            ? const Color(0xFFFDA4AF)
                                            : const Color(0xFF6EE7B7),
                                        width: 1.3,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isDeclined
                                              ? const Color(0xFFE11D48)
                                              : const Color(0xFF059669),
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isDeclined
                                                    ? (isSi
                                                        ? '💌 ආරාධනාව ප්‍රතික්ෂේප විය'
                                                        : '💌 Invitation Declined')
                                                    : (isSi
                                                        ? '🎉 මිතුරා ක්‍රීඩාවට එක් විය!'
                                                        : '🎉 Friend Joined the Game!'),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDeclined
                                                      ? const Color(0xFF9F1239)
                                                      : const Color(0xFF047857),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                isDeclined
                                                    ? (isSi
                                                        ? '$friendDisplay දැන් ක්‍රීඩාවට එක් වීමට නොහැකි බව දැන්වීය.'
                                                        : '$friendDisplay declined your game invitation.')
                                                    : (isSi
                                                        ? '✅ $friendDisplay ඔබේ ආරාධනාව පිළිගෙන ක්‍රීඩාවට එක් විය!'
                                                        : '✅ $friendDisplay accepted your invite and joined the game!'),
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.navy,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _unreadResponseNotifications
                                                  ?.removeAt(rIdx);
                                            });
                                            setDialogState(() {});
                                          },
                                          icon: const Icon(
                                            LucideIcons.x,
                                            size: 15,
                                          ),
                                          color: AppColors.muted,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildElderBellButton(BuildContext ctx) {
    final count = _totalNotificationCount;
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(),
          tooltip: widget.isSinhala ? 'දැනුම්දීම්' : 'Notifications',
          icon: Icon(
            LucideIcons.bell,
            size: 21,
            color: count > 0 ? const Color(0xFF2563EB) : AppColors.navy,
          ),
          onPressed: () => _openElderNotificationsDialog(ctx),
        ),
        if (count > 0)
          Positioned(
            top: 2,
            right: 2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.riskHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingNotificationCard(Map<String, dynamic> invite) {
    final isSi = widget.isSinhala;
    final invId = invite['id']?.toString() ?? '';
    final rawSender =
        (invite['senderName']?.toString() ?? 'Fellow Elder').trim();
    final senderDisplay = _formatSenderName(rawSender);
    final initial =
        rawSender.isNotEmpty ? rawSender.substring(0, 1).toUpperCase() : 'F';
    final totalCount = _pendingInvites.length;

    return TweenAnimationBuilder<double>(
      key: ValueKey('floating_invite_toast_$invId'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset((1 - value) * 60, 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 382,
          child: AuroraGradientBorderFrame(
            borderRadius: 22,
            borderWidth: 3.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top vibrant cosmic accent strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF312E81),
                            Color(0xFF7C3AED),
                            Color(0xFFDB2777),
                            Color(0xFF0D9488),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              '🔔',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSi
                                  ? 'නව ක්‍රීඩා ආරාධනාවක්! ($totalCount)'
                                  : 'New Game Invite! ($totalCount)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (invId.isNotEmpty) {
                                  _hiddenFloatingIds.add(invId);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Notification content + instant actions
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFFEC4899),
                                      Color(0xFF14B8A6),
                                    ],
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF2563EB),
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSi
                                          ? '🧺 විනෝද චාරිකා මතක ක්‍රීඩාව'
                                          : '🧺 Shared Picnic Memory Chain',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isSi
                                          ? '$senderDisplay ඔබට එකට සෙල්ලම් කිරීමට ආරාධනා කරයි!'
                                          : '$senderDisplay invited you to play together!',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF0D9488),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _respondToInvite(invite, accept: true),
                                    icon:
                                        const Icon(LucideIcons.check, size: 15),
                                    label: Text(
                                      isSi ? 'එක්වන්න' : 'Accept & Join',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 11,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              OutlinedButton(
                                onPressed: () =>
                                    _respondToInvite(invite, accept: false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  side: const BorderSide(
                                    color: Color(0xFFFCA5A5),
                                    width: 1.3,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: Text(
                                  isSi ? 'එපා' : 'Decline',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedJoinedFloatingCard(Map<String, dynamic> invite) {
    final isSi = widget.isSinhala;
    final invId = invite['id']?.toString() ?? '';
    final status = (invite['status']?.toString() ?? 'ACCEPTED').toUpperCase();
    final isDeclined = status == 'DECLINED';
    final rawFriend =
        (invite['targetName']?.toString() ?? 'Fellow Elder').trim();
    final friendDisplay = _formatSenderName(rawFriend);
    final initial =
        rawFriend.isNotEmpty ? rawFriend.substring(0, 1).toUpperCase() : 'F';

    return TweenAnimationBuilder<double>(
      key: ValueKey('floating_response_toast_${invId}_$status'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset((1 - value) * 60, 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 375,
          child: AuroraGradientBorderFrame(
            borderRadius: 22,
            borderWidth: 3.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDeclined
                        ? const [Color(0xFFFFFFFF), Color(0xFFFFF1F2)]
                        : const [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDeclined
                              ? const [
                                  Color(0xFF9F1239),
                                  Color(0xFFE11D48),
                                  Color(0xFFF59E0B),
                                ]
                              : const [
                                  Color(0xFF047857),
                                  Color(0xFF10B981),
                                  Color(0xFF0D9488),
                                ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            isDeclined ? '💌' : '🎉',
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDeclined
                                  ? (isSi
                                      ? 'ආරාධනාව ප්‍රතික්ෂේප විය'
                                      : 'Invitation Declined')
                                  : (isSi
                                      ? 'මිතුරා ක්‍රීඩාවට එක් විය!'
                                      : 'Friend Joined the Game!'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _acceptedToastTimer?.cancel();
                              setState(() {
                                _activeAcceptedToast = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isDeclined
                                    ? const [
                                        Color(0xFFF43F5E),
                                        Color(0xFFF59E0B),
                                        Color(0xFFEC4899),
                                      ]
                                    : const [
                                        Color(0xFF10B981),
                                        Color(0xFF06B6D4),
                                        Color(0xFF6366F1),
                                      ],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: isDeclined
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFF059669),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              isDeclined
                                  ? (isSi
                                      ? '$friendDisplay දැන් ක්‍රීඩාවට එක් වීමට නොහැකි බව දැන්වීය.'
                                      : '$friendDisplay declined your game invitation.')
                                  : (isSi
                                      ? '✅ $friendDisplay ඔබේ ආරාධනාව පිළිගෙන ක්‍රීඩාවට එක් විය!'
                                      : '✅ $friendDisplay accepted your invite and joined the game!'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinStartedLiveGame(Map<String, dynamic> liveRoom) async {
    final roomId = liveRoom['id']?.toString() ?? '';
    final myName = (widget.elderName ?? '').trim();
    if (roomId.isNotEmpty) {
      (_dismissedLiveRoomIds ??= <String>{}).add(roomId);
    }
    setState(() {
      _liveGameStartedPrompt = null;
    });

    if (roomId.isNotEmpty && myName.isNotEmpty) {
      final existingJoined = (liveRoom['joinedLivePlayers'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          <String>[];
      if (!existingJoined
          .any((n) => n.toLowerCase() == myName.toLowerCase())) {
        existingJoined.add(myName);
      }
      final updatedRoom = <String, dynamic>{
        ...liveRoom,
        'joinedLivePlayers': existingJoined,
      };
      try {
        final uri = Uri.parse(
          '${AppConfig.backendBaseUrl}/api/memory-games/invites',
        );
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        };
        await http
            .post(uri, headers: headers, body: jsonEncode(updatedRoom))
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    if (mounted) {
      context.go(
        '/dashboard/memory-games?game=collaborative&liveRoomId=${Uri.encodeComponent(roomId)}',
      );
    }
  }

  Widget _buildLiveGameStartedFloatingCard(Map<String, dynamic> liveRoom) {
    final isSi = widget.isSinhala;
    final roomId = liveRoom['id']?.toString() ?? '';
    final rawStarter =
        (liveRoom['startedBy']?.toString() ?? 'Fellow Elder').trim();
    final starterDisplay = _formatSenderName(rawStarter);
    final initial =
        rawStarter.isNotEmpty ? rawStarter.substring(0, 1).toUpperCase() : 'G';

    return TweenAnimationBuilder<double>(
      key: ValueKey('floating_live_started_$roomId'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset((1 - value) * 60, 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 390,
          child: AuroraGradientBorderFrame(
            borderRadius: 22,
            borderWidth: 3.2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFECFDF5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1E1B4B),
                            Color(0xFF7C3AED),
                            Color(0xFF059669),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🚀', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSi
                                  ? 'ක්‍රීඩාව ආරම්භ වුණා! ඉක්මනින් එක්වන්න!'
                                  : 'Game Started! Join Quickly!',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (roomId.isNotEmpty) {
                                (_dismissedLiveRoomIds ??= <String>{})
                                    .add(roomId);
                              }
                              setState(() {
                                _liveGameStartedPrompt = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF7C3AED),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  isSi
                                      ? '$starterDisplay ක්‍රීඩාව ආරම්භ කළා! එකට සෙල්ලම් කිරීමට දැන්ම ඉක්මනින් එක්වන්න!'
                                      : '$starterDisplay started the Picnic Game! Tap below to join quickly!',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF0D9488),
                                  Color(0xFF2563EB),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _joinStartedLiveGame(liveRoom),
                              icon: const Icon(LucideIcons.gamepad2, size: 17),
                              label: Text(
                                isSi
                                    ? 'ඉක්මනින් එක්වන්න!'
                                    : 'Join Game Now!',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.builder(context, const SizedBox.shrink());
    }

    final visibleFloating = _pendingInvites.where((inv) {
      final id = inv['id']?.toString() ?? '';
      return id.isNotEmpty && !_hiddenFloatingIds.contains(id);
    }).toList();

    final hasAnyFloating = visibleFloating.isNotEmpty ||
        _activeAcceptedToast != null ||
        _liveGameStartedPrompt != null;

    return Stack(
      children: [
        widget.builder(context, _buildElderBellButton(context)),
        if (hasAnyFloating)
          Positioned(
            top: 82,
            right: 20,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_liveGameStartedPrompt != null)
                      _buildLiveGameStartedFloatingCard(
                        _liveGameStartedPrompt!,
                      ),
                    if (_liveGameStartedPrompt != null &&
                        (_activeAcceptedToast != null ||
                            visibleFloating.isNotEmpty))
                      const SizedBox(height: 10),
                    if (_activeAcceptedToast != null)
                      _buildAcceptedJoinedFloatingCard(_activeAcceptedToast!),
                    if (_activeAcceptedToast != null &&
                        visibleFloating.isNotEmpty)
                      const SizedBox(height: 10),
                    if (visibleFloating.isNotEmpty)
                      _buildFloatingNotificationCard(visibleFloating.first),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Continuously animated colorful Aurora gradient border frame for attractive elder cards & dialogs.
class AuroraGradientBorderFrame extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;

  const AuroraGradientBorderFrame({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.borderWidth = 3.2,
  });

  @override
  State<AuroraGradientBorderFrame> createState() =>
      _AuroraGradientBorderFrameState();
}

class _AuroraGradientBorderFrameState extends State<AuroraGradientBorderFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        return Container(
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              transform: GradientRotation(angle),
              colors: const [
                Color(0xFF6366F1),
                Color(0xFFA855F7),
                Color(0xFFEC4899),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Color(0xFF06B6D4),
                Color(0xFF6366F1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(-4, 10),
              ),
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(4, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
