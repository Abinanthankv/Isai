import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setOpen(bool isOpen) => state = isOpen;
}

final isPlayerOpenProvider = NotifierProvider<PlayerOpenNotifier, bool>(() {
  return PlayerOpenNotifier();
});
