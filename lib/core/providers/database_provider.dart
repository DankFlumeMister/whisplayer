import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/data/db/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
