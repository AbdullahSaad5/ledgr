// Fails CI when line coverage for lib/ (excluding generated/boilerplate files)
// drops below the threshold. Reads coverage/lcov.info produced by
// `flutter test --coverage`.
import 'dart:io';

const _threshold = 80.0;

/// Files excluded from the coverage gate: generated code and pure wiring with
/// no meaningful branches to cover.
bool _excluded(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.contains('/l10n/generated/') ||
      path.endsWith('lib/main.dart') ||
      // DB open wiring (real device I/O; overridden in tests).
      path.endsWith('lib/core/db/connection.dart') ||
      path.endsWith('lib/core/providers/database_provider.dart') ||
      // Declarative Drift schema — column getters are metadata, not executable
      // logic; the schema is exercised behaviourally by the DB tests through
      // the generated code.
      path.endsWith('lib/core/db/tables.dart');
}

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found — run flutter test --coverage');
    exit(1);
  }

  var found = 0;
  var hit = 0;
  String? current;
  var skip = false;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      skip = _excluded(current);
    } else if (!skip && line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final count = int.tryParse(parts[1]) ?? 0;
      found++;
      if (count > 0) hit++;
    }
  }

  final pct = found == 0 ? 100.0 : (hit / found) * 100;
  stdout.writeln(
    'Coverage: ${pct.toStringAsFixed(1)}% '
    '($hit/$found lines) — threshold $_threshold%',
  );
  if (pct < _threshold) {
    stderr.writeln('FAIL: coverage below threshold');
    exit(1);
  }
  stdout.writeln('PASS');
}
