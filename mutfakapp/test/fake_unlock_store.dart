/// Bellekte tutan [UnlockStore] — testler platform eklentisi kurmasın.
library;

import 'package:mutfakapp/src/lock/unlock_password.dart';

class FakeUnlockStore implements UnlockStore {
  FakeUnlockStore({this.unlocked = false});

  bool unlocked;

  @override
  Future<bool> isUnlocked() async => unlocked;

  @override
  Future<void> remember() async => unlocked = true;
}
