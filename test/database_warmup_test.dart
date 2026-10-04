import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database_warmup.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Regression test for the startup race that left every list page empty until
/// the user manually reloaded: the database executor opens lazily, so the
/// very first query could fire before it was ready. [warmUpDatabase] (called
/// from main() before runApp) must open the database and prove it answers.
void main() {
  test('warmUpDatabase opens the database so first queries succeed', () async {
    ensureSqlite();
    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    await warmUpDatabase(db);

    // The database answers queries right after the warm-up — no race left
    // for the first list page to hit.
    final rows = await db.customSelect('SELECT 1 AS one').get();
    expect(rows.single.read<int>('one'), 1);
  });

  test('warmUpDatabase never throws, even on a closed database', () async {
    ensureSqlite();
    final db = AppDatabase.forTesting();
    await db.close();

    // Must not block app startup if the database cannot open; pages keep
    // their own error handling.
    await warmUpDatabase(db);
  });
}
