import 'package:daily_apps/models/model_serious_mode.dart';
import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/serious_mode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Serious Mode Model & Leaderboard Tests', () {
    test('SeriousUser serialization and password preservation', () {
      final user = SeriousUser(
        id: 'usr_123',
        username: 'bima_pro',
        password: 'secretPassword123',
        displayName: 'Bima Satria',
        avatarIndex: 2,
        totalPoints: 120,
        totalTasksCompleted: 45,
        totalPunishmentsTaken: 1,
      );

      final json = user.toJson();
      expect(json['username'], 'bima_pro');
      expect(json['password'], 'secretPassword123');
      expect(json['displayName'], 'Bima Satria');
      expect(json['totalPoints'], 120);

      final fromJson = SeriousUser.fromJson(json);
      expect(fromJson.id, 'usr_123');
      expect(fromJson.username, 'bima_pro');
      expect(fromJson.password, 'secretPassword123');
      expect(fromJson.displayName, 'Bima Satria');
      expect(fromJson.totalPoints, 120);
      expect(fromJson.totalTasksCompleted, 45);
    });

    test('Point calculation based on completed tasks count', () {
      expect(SeriousModeService.calculatePoints(0), 0);
      expect(SeriousModeService.calculatePoints(1), 1);
      expect(SeriousModeService.calculatePoints(2), 1);
      expect(SeriousModeService.calculatePoints(3), 2);
      expect(SeriousModeService.calculatePoints(5), 2);
      expect(SeriousModeService.calculatePoints(6), 4);
      expect(SeriousModeService.calculatePoints(8), 4);
      expect(SeriousModeService.calculatePoints(9), 5);
      expect(SeriousModeService.calculatePoints(10), 5);
      expect(SeriousModeService.calculatePoints(11), 7);
      expect(SeriousModeService.calculatePoints(15), 7);
      expect(SeriousModeService.calculatePoints(16), 10);
      expect(SeriousModeService.calculatePoints(30), 10);
    });

    test('Leaderboard sorting yields highest points on top 3 podium', () {
      final users = [
        SeriousUser(
          id: 'u1',
          username: 'user1',
          password: '123',
          displayName: 'Pemain 1',
          totalPoints: 50,
          totalTasksCompleted: 20,
        ),
        SeriousUser(
          id: 'u2',
          username: 'user2',
          password: '123',
          displayName: 'Pemain 2',
          totalPoints: 120,
          totalTasksCompleted: 40,
        ),
        SeriousUser(
          id: 'u3',
          username: 'user3',
          password: '123',
          displayName: 'Pemain 3',
          totalPoints: 90,
          totalTasksCompleted: 35,
        ),
        SeriousUser(
          id: 'u4',
          username: 'user4',
          password: '123',
          displayName: 'Pemain 4',
          totalPoints: 10,
          totalTasksCompleted: 5,
        ),
      ];

      users.sort((a, b) {
        final cmp = b.totalPoints.compareTo(a.totalPoints);
        if (cmp != 0) return cmp;
        return b.totalTasksCompleted.compareTo(a.totalTasksCompleted);
      });

      final top3 = users.take(3).toList();
      expect(top3.length, 3);
      expect(top3[0].username, 'user2'); // 120 pts
      expect(top3[1].username, 'user3'); // 90 pts
      expect(top3[2].username, 'user1'); // 50 pts
    });

    test('Section evaluation properly tags incomplete past sections', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final group = TodoDateGroup(
        id: 'past_group_1',
        date: pastDate,
        items: [
          TodoItem(id: 't1', title: 'Task 1', isCompleted: true),
          TodoItem(id: 't2', title: 'Task 2', isCompleted: false),
        ],
      );

      final eval = SeriousModeService.evaluateSection(group);
      expect(eval, isNotNull);
      expect(eval!.completedCount, 1);
      expect(eval.pendingCount, 1);
      expect(eval.isPunishmentRequired, isTrue);
      expect(eval.pointsEarned, 1);
    });

    test('20 Physical workout punishment items are properly configured', () {
      final list = SeriousModeService.punishmentList;
      expect(list.length, 20);
      for (final item in list) {
        expect(item.id.isNotEmpty, isTrue);
        expect(item.title.isNotEmpty, isTrue);
        expect(item.category, 'Fisik');
        expect(item.emoji.isNotEmpty, isTrue);
        expect(item.repsOrDuration.isNotEmpty, isTrue);
        expect(item.targetMuscle.isNotEmpty, isTrue);
      }
    });

    test('Punishment state creation assigns N workouts matching pending count', () async {
      const groupId = 'test_group_missed_3';
      const pendingCount = 3;

      final state = await SeriousModeService.getOrCreatePunishmentState(groupId, pendingCount);
      expect(state.groupId, groupId);
      expect(state.assignedPunishmentIds.length, 3);
      expect(state.completedPunishmentIds.isEmpty, isTrue);
      expect(state.isFullyCompleted, isFalse);
      expect(state.isSurrendered, isFalse);

      final items = SeriousModeService.getPunishmentItemsByIds(state.assignedPunishmentIds);
      expect(items.length, 3);
    });

    test('Point recalculation applies -1 penalty per unpunished missed task or full points upon completion', () async {
      final user = SeriousUser(
        id: 'u_test',
        username: 'athlete_user',
        password: '123',
        displayName: 'Athlete',
        totalPoints: 0,
      );
      await SeriousModeService.saveCurrentUser(user);

      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final pastGroup = TodoDateGroup(
        id: 'group_yesterday',
        date: pastDate,
        items: [
          TodoItem(id: 't1', title: 'Task 1', isCompleted: true),
          TodoItem(id: 't2', title: 'Task 2', isCompleted: true),
          TodoItem(id: 't3', title: 'Task 3', isCompleted: false),
          TodoItem(id: 't4', title: 'Task 4', isCompleted: false),
          TodoItem(id: 't5', title: 'Task 5', isCompleted: false),
        ],
      );

      // Skenario 1: Belum menyelesaikan hukuman (2 selesai -> calculatePoints(2) = 1 pt, 3 missed -> penalty -3, net = -2)
      await SeriousModeService.recalculateAndSyncUserProgress([pastGroup]);
      var updatedUser = await SeriousModeService.getCurrentUser();
      expect(updatedUser?.totalPoints, -2);

      // Skenario 2: Menyelesaikan seluruh 3 hukuman olahraga fisik
      final state = await SeriousModeService.getOrCreatePunishmentState(pastGroup.id, pastGroup.pendingCount);
      for (final pid in state.assignedPunishmentIds) {
        await SeriousModeService.togglePunishmentItemCompleted(
          groupId: pastGroup.id,
          punishmentId: pid,
          allGroups: [pastGroup],
        );
      }

      updatedUser = await SeriousModeService.getCurrentUser();
      // Total 5 tugas terjadwal pada hari itu -> calculatePoints(5) = 2 pts
      expect(updatedUser?.totalPoints, 2);
    });

    test('User-scoped keys are properly formatted and prevent account data collision', () {
      expect(
        SeriousModeService.getSeriousTodoGroupsKey('usr_alpha'),
        'daily_apps_serious_todo_groups_v1_usr_alpha',
      );
      expect(
        SeriousModeService.getSeriousTodoGroupsKey(null),
        'daily_apps_serious_todo_groups_v1',
      );
      expect(
        SeriousModeService.getPunishmentStatesKey('usr_beta'),
        'daily_apps_serious_punishment_states_v1_usr_beta',
      );
    });

    test('Multi-account isolation maintains independent tasks and progress', () async {
      // User 1
      final user1 = SeriousUser(
        id: 'user_1',
        username: 'budi_serius',
        password: 'pass1',
        displayName: 'Budi',
        totalPoints: 0,
      );
      await SeriousModeService.saveCurrentUser(user1);
      await SeriousModeService.setSeriousModeActive(true);

      final prefs = await SharedPreferences.getInstance();
      final keyUser1 = SeriousModeService.getSeriousTodoGroupsKey(user1.id);
      await prefs.setString(keyUser1, '[{"id":"g1","date":"2026-09-01T00:00:00.000","items":[{"id":"t1","title":"Task Budi","isCompleted":true}]}]');

      final groups1 = [
        TodoDateGroup(
          id: 'g1',
          date: DateTime.now(),
          items: [TodoItem(id: 't1', title: 'Task Budi', isCompleted: true)],
        ),
      ];
      await SeriousModeService.recalculateAndSyncUserProgress(groups1, targetUser: user1);
      final refreshedUser1 = await SeriousModeService.getCurrentUser();
      expect(refreshedUser1?.totalPoints, 1);
      expect(refreshedUser1?.totalTasksCompleted, 1);

      // User 2 logs in
      final user2 = SeriousUser(
        id: 'user_2',
        username: 'ani_produktif',
        password: 'pass2',
        displayName: 'Ani',
        totalPoints: 0,
      );
      await SeriousModeService.saveCurrentUser(user2);
      final keyUser2 = SeriousModeService.getSeriousTodoGroupsKey(user2.id);

      // Key for User 2 should be empty (not containing Budi's tasks)
      expect(prefs.getString(keyUser2), isNull);

      final groups2 = [
        TodoDateGroup(
          id: 'g2',
          date: DateTime.now(),
          items: [
            TodoItem(id: 't2a', title: 'Task Ani 1', isCompleted: true),
            TodoItem(id: 't2b', title: 'Task Ani 2', isCompleted: true),
            TodoItem(id: 't2c', title: 'Task Ani 3', isCompleted: true),
          ],
        ),
      ];
      await SeriousModeService.recalculateAndSyncUserProgress(groups2, targetUser: user2);
      final refreshedUser2 = await SeriousModeService.getCurrentUser();
      expect(refreshedUser2?.totalPoints, 2); // 3 completed tasks -> 2 pts
      expect(refreshedUser2?.totalTasksCompleted, 3);

      // Budi logs back in
      await SeriousModeService.saveCurrentUser(user1);
      expect(prefs.getString(keyUser1), isNotNull);
      expect(prefs.getString(keyUser1)!.contains('Task Budi'), isTrue);
    });

    test('Commitment warning preference toggle can be saved and retrieved per user', () async {
      expect(await SeriousModeService.isHideCommitmentWarning('usr_test'), isFalse);
      await SeriousModeService.setHideCommitmentWarning(true, 'usr_test');
      expect(await SeriousModeService.isHideCommitmentWarning('usr_test'), isTrue);
      // Other user still false
      expect(await SeriousModeService.isHideCommitmentWarning('usr_other'), isFalse);
    });

    test('Login with existing user preserves spreadsheet points when local groups is empty', () async {
      final user = SeriousUser(
        id: 'usr_chandra',
        username: 'chandra',
        password: '123',
        displayName: 'Chandra',
        totalPoints: 45,
        totalTasksCompleted: 30,
      );
      await SeriousModeService.saveCurrentUser(user);

      // Calling recalculate with empty groups must NOT reset points to 0
      await SeriousModeService.recalculateAndSyncUserProgress([], targetUser: user);
      final refreshed = await SeriousModeService.getCurrentUser();
      expect(refreshed?.totalPoints, 45);
      expect(refreshed?.totalTasksCompleted, 30);
    });

    test('findExistingUserTodoData reliably recovers tasks across legacy or username keys', () async {
      final prefs = await SharedPreferences.getInstance();
      final user = SeriousUser(
        id: 'usr_999',
        username: 'player_one',
        password: '123',
        displayName: 'Player One',
      );

      // Save under legacy key
      await prefs.setString(SeriousModeService.prefKeySeriousTodoGroups, '[{"id":"legacy_group"}]');
      final found1 = await SeriousModeService.findExistingUserTodoData(prefs, user);
      expect(found1, contains('legacy_group'));

      // Save under username key
      final userKey = SeriousModeService.getSeriousTodoGroupsKey(SeriousModeService.getUserStorageIdentifier(user));
      await prefs.setString(userKey, '[{"id":"user_group"}]');
      final found2 = await SeriousModeService.findExistingUserTodoData(prefs, user);
      expect(found2, contains('user_group'));
    });

    test('Apps Script template code provides get_serious_tasks and sync_serious_tasks', () {
      final code = SeriousModeService.getSeriousModeAppsScriptCode();
      expect(code, contains('get_serious_tasks'));
      expect(code, contains('sync_serious_tasks'));
      expect(code, contains('Tasks_Mode_Serius'));
    });
  });
}
