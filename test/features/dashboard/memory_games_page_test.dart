import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:carevora/features/assessment/application/memory_game_service.dart';
import 'package:carevora/features/auth/application/auth_controller.dart';
import 'package:carevora/features/dashboard/presentation/memory_games_page.dart';
import 'package:carevora/shared/widgets/desktop_sidebar.dart';

class MockElderAuthNotifier extends AuthNotifier {
  @override
  AuthState get state => const AuthState(
        isAuthenticated: true,
        userName: 'Sarah Jenkins',
        role: UserRole.elder,
        residentId: 1,
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        token: 'test-elder-token',
      );
}

class MockCaregiverAuthNotifier extends AuthNotifier {
  @override
  AuthState get state => const AuthState(
        isAuthenticated: true,
        userName: 'Eleanor Vance',
        role: UserRole.caregiver,
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        token: 'test-caregiver-token',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MemoryGameService.client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 1,
            'sessionId': 'MG-TEST-123',
            'residentId': 1,
            'residentName': 'Sarah Jenkins',
            'gameType': 'ITEMS',
            'scorePercentage': 100.0,
            'attempts': 1,
            'correctAnswers': 4,
            'totalItems': 4,
            'status': 'COMPLETED',
            'completedAt': DateTime.now().toIso8601String(),
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    MemoryGameService.client = null;
  });

  Widget createSidebarWidget({required bool isElder}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => isElder ? MockElderAuthNotifier() : MockCaregiverAuthNotifier(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DesktopSidebar(
            currentRoute: '/dashboard/memory-games',
            isCollapsed: false,
          ),
        ),
      ),
    );
  }

  Widget createMemoryGamesWidget({
    MemoryGameType initialGame = MemoryGameType.none,
    List<int>? initialSequence,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => MockElderAuthNotifier()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 900)),
          child: MemoryGamesPage(
            initialGame: initialGame,
            initialSequence: initialSequence,
          ),
        ),
      ),
    );
  }

  group('Memory Games - Elder Navigation & Sidebar Tests', () {
    testWidgets('1. Elder sidebar renders Memory Games item immediately above Settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createSidebarWidget(isElder: true));
      await tester.pumpAndSettle();

      expect(find.text('Memory Games'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify Memory Games is rendered before Settings in widget order
      final memoryGamesY = tester.getTopLeft(find.text('Memory Games')).dy;
      final settingsY = tester.getTopLeft(find.text('Settings')).dy;
      expect(memoryGamesY, lessThan(settingsY));
    });

    testWidgets('2. Caregiver sidebar does NOT render Memory Games item', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createSidebarWidget(isElder: false));
      await tester.pumpAndSettle();

      expect(find.text('Memory Games'), findsNothing);
      expect(find.text('Doctor Prescribing'), findsOneWidget);
      expect(find.text('Live Medicine Board'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('Memory Games - Hub View Tests', () {
    testWidgets('3. Hub view displays gentle banner and 3 game cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createMemoryGamesWidget());
      await tester.pumpAndSettle();

      // Header and wellness notes
      expect(find.text('Memory Games'), findsOneWidget);
      expect(find.text('Gentle Brain Practice'), findsOneWidget);
      expect(find.textContaining('There are no timers, no scores recorded, and no penalties'), findsOneWidget);

      // 3 Game Cards
      expect(find.text('Remember the Sequence'), findsOneWidget);
      expect(find.text('Find the Matching Pairs'), findsOneWidget);
      expect(find.text('Remember the Items'), findsOneWidget);

      // Play buttons
      expect(find.text('Play Sequence'), findsOneWidget);
      expect(find.text('Play Matching Pairs'), findsOneWidget);
      expect(find.text('Play Remember Items'), findsOneWidget);
    });
  });

  group('Game 1: Remember the Sequence Tests', () {
    testWidgets('4. Sequence game starts at 3 items and transitions through phases', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.sequence));
      await tester.pumpAndSettle();

      // Top nav bar
      expect(find.text('Remember the Sequence'), findsOneWidget);
      expect(find.textContaining('Level 1 (3 Tiles)'), findsOneWidget);

      // Preview phase
      expect(find.text('Watch & Remember the Sequence'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Step 3'), findsOneWidget);

      final startButton = find.byKey(const ValueKey('start_sequence_input_button'));
      expect(startButton, findsOneWidget);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Input phase
      expect(find.text('Your Turn: Tap the Tiles in Order'), findsOneWidget);
      expect(find.textContaining('Progress: 0 of 3 tiles tapped'), findsOneWidget);

      // Tapping tiles
      final tile0 = find.byKey(const ValueKey('sequence_tile_0'));
      expect(tile0, findsOneWidget);
      await tester.tap(tile0);
      await tester.pumpAndSettle();

      // Replay sequence button returns to preview
      final replayButton = find.byKey(const ValueKey('replay_sequence_button'));
      if (replayButton.evaluate().isNotEmpty) {
        await tester.tap(replayButton);
        await tester.pumpAndSettle();
        expect(find.text('Watch & Remember the Sequence'), findsOneWidget);
      }
    });

    testWidgets('5. Sequence game returns to Hub view on back button tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.sequence));
      await tester.pumpAndSettle();

      final backButton = find.byKey(const ValueKey('back_to_games_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Returned to Hub
      expect(find.text('Choose a Game to Play'), findsOneWidget);
      expect(find.text('Play Sequence'), findsOneWidget);
    });
  });

  group('Game 2: Find the Matching Pairs Tests', () {
    testWidgets('6. Matching pairs game displays grid of 12 cards and tracks pairs found', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.pairs));
      await tester.pumpAndSettle();

      expect(find.text('Find the Matching Pairs'), findsOneWidget);
      expect(find.text('Pairs Found: 0 / 6'), findsOneWidget);

      // Verify 12 cards are displayed
      for (int i = 0; i < 12; i++) {
        expect(find.byKey(ValueKey('pair_card_$i')), findsOneWidget);
      }

      // Tap first card
      await tester.tap(find.byKey(const ValueKey('pair_card_0')));
      await tester.pumpAndSettle();

      // Tap second card
      await tester.tap(find.byKey(const ValueKey('pair_card_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300)); // allow mismatch timer if needed

      // Restart button works cleanly
      final restartBtn = find.byKey(const ValueKey('restart_pairs_button'));
      expect(restartBtn, findsOneWidget);
      await tester.ensureVisible(restartBtn);
      await tester.pumpAndSettle();
      await tester.tap(restartBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pairs Found: 0 / 6'), findsOneWidget);
    });

    testWidgets('7. Matching pairs returns to Hub view on back button tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.pairs));
      await tester.pumpAndSettle();

      final backButton = find.byKey(const ValueKey('back_to_games_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Choose a Game to Play'), findsOneWidget);
      expect(find.text('Play Matching Pairs'), findsOneWidget);
    });
  });

  group('Game 3: Remember the Items Tests', () {
    testWidgets('8. Remember items starts in study phase, transitions to select, and shows feedback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.items));
      await tester.pumpAndSettle();

      // Study phase
      expect(find.text('Remember the Items'), findsOneWidget);
      expect(find.text('Take a look at these 4 familiar items'), findsOneWidget);

      final continueButton = find.byKey(const ValueKey('ready_items_button'));
      expect(continueButton, findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Selection phase
      expect(find.text('Which items do you remember seeing?'), findsOneWidget);
      expect(find.text('Selected: 0 of 4'), findsOneWidget);

      // Select an item option
      final firstOption = find.byKey(const ValueKey('item_option_1'));
      if (firstOption.evaluate().isNotEmpty) {
        await tester.tap(firstOption);
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Picked'), findsOneWidget);
      } else {
        // Find any item_option widget
        final anyOption = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('item_option_'),
        );
        expect(anyOption, findsWidgets);
        await tester.tap(anyOption.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Picked'), findsOneWidget);
      }

      // Check answers
      final checkAnswersBtn = find.byKey(const ValueKey('check_answers_button'));
      expect(checkAnswersBtn, findsOneWidget);
      await tester.tap(checkAnswersBtn);
      await tester.pumpAndSettle();

      // Feedback phase
      expect(find.text('Review Your Answers'), findsOneWidget);
      expect(find.byKey(const ValueKey('play_items_new_round_button')), findsOneWidget);

      // Start new round
      await tester.tap(find.byKey(const ValueKey('play_items_new_round_button')));
      await tester.pumpAndSettle();
      expect(find.text('Take a look at these 4 familiar items'), findsOneWidget);
    });

    testWidgets('9. Remember items returns to Hub view on back button tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.items));
      await tester.pumpAndSettle();

      final backButton = find.byKey(const ValueKey('back_to_games_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Choose a Game to Play'), findsOneWidget);
      expect(find.text('Play Remember Items'), findsOneWidget);
    });

    testWidgets('10. Sequence game: correct sequence input triggers Well done and increases difficulty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      await tester.pumpWidget(createMemoryGamesWidget(
        initialGame: MemoryGameType.sequence,
        initialSequence: [0, 1, 2],
      ));
      await tester.pumpAndSettle();

      // Start input
      await tester.tap(find.byKey(const ValueKey('start_sequence_input_button')));
      await tester.pumpAndSettle();

      // Tap the exact sequence 0, 1, 2
      await tester.tap(find.byKey(const ValueKey('sequence_tile_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sequence_tile_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sequence_tile_2')));
      await tester.pumpAndSettle();

      // Verified celebration banner and next round button
      expect(find.textContaining('Well done!'), findsWidgets);
      expect(find.text('Next Round (4 Tiles)'), findsOneWidget);

      // Advance to Level 2
      await tester.tap(find.byKey(const ValueKey('next_level_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Level 2 (4 Tiles)'), findsOneWidget);
      expect(find.text('Step 4'), findsOneWidget);
    });

    testWidgets('11. Sequence game: wrong tile triggers encouraging retry feedback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      await tester.pumpWidget(createMemoryGamesWidget(
        initialGame: MemoryGameType.sequence,
        initialSequence: [0, 1, 2],
      ));
      await tester.pumpAndSettle();

      // Start input
      await tester.tap(find.byKey(const ValueKey('start_sequence_input_button')));
      await tester.pumpAndSettle();

      // Tap tiles completing the sequence with an incorrect tile (tile 3 instead of 0, then 1, then 2)
      await tester.tap(find.byKey(const ValueKey('sequence_tile_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sequence_tile_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sequence_tile_2')));
      await tester.pumpAndSettle();

      // Encouraging message
      expect(find.text('Good try!'), findsWidgets);
      expect(find.textContaining('Would you like to play again?'), findsOneWidget);
      expect(find.byKey(const ValueKey('try_again_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('reset_level_1_button')), findsOneWidget);

      // Try again returns to preview
      await tester.tap(find.byKey(const ValueKey('try_again_button')));
      await tester.pumpAndSettle();
      expect(find.text('Watch & Remember the Sequence'), findsOneWidget);
    });

    testWidgets('12. Remember items: matching all 4 targets produces perfect accuracy feedback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      await tester.pumpWidget(createMemoryGamesWidget(initialGame: MemoryGameType.items));
      await tester.pumpAndSettle();

      // Identify the 4 items shown in study phase
      final studyItems = <String>[];
      final itemNames = [
        'Red Apple', 'Story Book', 'Pink Flower', 'Wall Clock', 'Tea Cup',
        'Cozy House', 'Bright Sun', 'Loving Heart', 'Brass Bell', 'Brass Key',
      ];
      for (final name in itemNames) {
        if (find.text(name).evaluate().isNotEmpty) {
          studyItems.add(name);
        }
      }
      expect(studyItems.length, equals(4));

      // Continue to selection
      await tester.tap(find.byKey(const ValueKey('ready_items_button')));
      await tester.pumpAndSettle();

      // Select the 4 studied items
      for (final name in studyItems) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }

      // Check answers
      await tester.tap(find.byKey(const ValueKey('check_answers_button')));
      await tester.pumpAndSettle();

      // Verification of celebratory message
      expect(find.text('Well done! All items correct!'), findsOneWidget);
      expect(find.textContaining('You remembered every single item with great accuracy!'), findsOneWidget);
      expect(find.text('Correct! ✅'), findsNWidgets(4));
    });
  });
}
