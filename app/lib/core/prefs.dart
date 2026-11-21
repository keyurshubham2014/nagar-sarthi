import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() before runApp, so session, ward and language are known on the first frame.
final prefsProvider = Provider<SharedPreferences>((_) => throw StateError('prefsProvider is overridden in main()'));

const String kDefaultWard = 'E';

/// The ward the app is about (Home, Audit, My Ward). Default E; survives restarts.
class ChosenWard extends Notifier<String> {
  @override
  String build() => ref.read(prefsProvider).getString('ward') ?? kDefaultWard;

  void set(String code) {
    state = code;
    ref.read(prefsProvider).setString('ward', code);
  }
}

final chosenWardProvider = NotifierProvider<ChosenWard, String>(ChosenWard.new);
