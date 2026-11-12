import 'package:nexo/features/auth/application/account_deletion.dart';

class FakeUserDataEraser implements UserDataEraser {
  const FakeUserDataEraser();

  @override
  Future<void> eraseAll(String uid) async {}
}
