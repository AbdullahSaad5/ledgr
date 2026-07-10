import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/features/backup/data/auto_backup_service.dart';

void main() {
  test('snapshot writes a dated JSON export into backups/', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final docs = await Directory.systemTemp.createTemp('ledgr_backup_test');
    addTearDown(() async {
      await db.close();
      await docs.delete(recursive: true);
    });

    final file = await AutoBackupService.snapshot(db, docs);
    expect(file.existsSync(), isTrue);
    expect(file.path, contains('backups/auto_'));
    expect(await file.readAsString(), contains('"categories"'));
    expect(await AutoBackupService.latest(docs), isNotNull);
  });

  test('pruneList keeps the newest 7 snapshots', () {
    final files = [
      for (var d = 1; d <= 10; d++)
        File('backups/auto_2026-07-${d.toString().padLeft(2, '0')}.json'),
    ];
    final stale = AutoBackupService.pruneList(files);
    expect(stale.map((f) => f.path), [
      'backups/auto_2026-07-03.json',
      'backups/auto_2026-07-02.json',
      'backups/auto_2026-07-01.json',
    ]);
  });

  test('pruneList ignores non-snapshot files', () {
    final files = [
      File('backups/auto_2026-07-01.json'),
      File('backups/manual_export.json'),
    ];
    expect(AutoBackupService.pruneList(files), isEmpty);
  });
}
