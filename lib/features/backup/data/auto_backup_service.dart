import 'dart:io';

import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/features/backup/data/backup_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Daily local JSON snapshots (#17): a workmanager task exports the full
/// backup into `<documents>/backups/` once a day and keeps only the newest
/// [keep]. Fully offline — nothing ever leaves the device.
class AutoBackupService {
  const AutoBackupService();

  static const taskName = 'ledgr-auto-backup';
  static const keep = 7;

  /// Runs one snapshot against [db] into [docs]/backups. Returns the file.
  /// Extracted so both the background task and the settings toggle (which
  /// snapshots immediately on enable) share the exact same path.
  static Future<File> snapshot(AppDatabase db, Directory docs) async {
    final dir = Directory('${docs.path}/backups');
    await dir.create(recursive: true);

    final now = DateTime.now();
    final stamp =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/auto_$stamp.json');
    await file.writeAsString(await BackupService(db).export());

    for (final stale in pruneList(
      dir.listSync().whereType<File>().toList(),
    )) {
      await stale.delete();
    }
    return file;
  }

  /// Which snapshot files to delete so only the newest [keep] remain. The
  /// date-stamped names sort chronologically, so ordering is by name.
  static List<File> pruneList(List<File> files, {int keep = keep}) {
    final snapshots =
        files.where((f) => f.path.split('/').last.startsWith('auto_')).toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return snapshots.length <= keep ? const [] : snapshots.sublist(keep);
  }

  /// The newest snapshot on disk, if any. Filters to `auto_` files with the
  /// same rule as [pruneList], so a stray file in the folder is never shared
  /// as "the latest auto-backup".
  static Future<File?> latest(Directory docs) async {
    final dir = Directory('${docs.path}/backups');
    if (!dir.existsSync()) return null;
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.split('/').last.startsWith('auto_'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return files.isEmpty ? null : files.first;
  }

  Future<void> enable() async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(days: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> disable() => Workmanager().cancelByUniqueName(taskName);
}

/// Background entry point. Runs in its own isolate, so it opens its own
/// database handle and closes it before returning.
@pragma('vm:entry-point')
void autoBackupDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Belt and braces: disable() cancels the schedule, but if a stale task
    // fires anyway it must respect the user's setting.
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('autoBackupEnabled') ?? false)) return true;

    final db = AppDatabase();
    try {
      final docs = await getApplicationDocumentsDirectory();
      await AutoBackupService.snapshot(db, docs);
    } finally {
      await db.close();
    }
    return true;
  });
}
