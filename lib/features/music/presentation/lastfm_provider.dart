import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../../settings/data/lastfm_repository.dart';
import '../data/lastfm_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class LastfmState {
  final bool isConnected;
  final String? username;
  final bool isConnecting;
  final bool hasPendingToken;
  final String? error;

  LastfmState({
    this.isConnected = false,
    this.username,
    this.isConnecting = false,
    this.hasPendingToken = false,
    this.error,
  });

  LastfmState copyWith({
    bool? isConnected,
    String? username,
    bool? isConnecting,
    bool? hasPendingToken,
    String? error,
  }) {
    return LastfmState(
      isConnected: isConnected ?? this.isConnected,
      username: username ?? this.username,
      isConnecting: isConnecting ?? this.isConnecting,
      hasPendingToken: hasPendingToken ?? this.hasPendingToken,
      error: error,
    );
  }
}

final lastfmProvider = NotifierProvider<LastfmNotifier, LastfmState>(() {
  return LastfmNotifier();
});

class LastfmNotifier extends Notifier<LastfmState> {
  late final LastfmRepository _repo;
  late final LastFmService _service;
  String? _currentToken;

  @override
  LastfmState build() {
    _repo = getIt<LastfmRepository>();
    _service = getIt<LastFmService>();
    return LastfmState(
      isConnected: _repo.isConnected,
      username: _repo.username,
    );
  }

  bool get hasToken => _currentToken != null;

  Future<void> connect() async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final token = await _service.fetchToken();
      if (token == null) {
        state = state.copyWith(isConnecting: false, error: 'Failed to fetch token');
        return;
      }
      _currentToken = token;
      state = state.copyWith(isConnecting: true, hasPendingToken: true);
      final authUrl = Uri.parse('https://www.last.fm/api/auth/?api_key=${LastFmService.apiKey}&token=$token');
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        state = state.copyWith(isConnecting: false, error: 'Could not launch browser');
      }
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e.toString());
    }
  }

  Future<void> completeConnection() async {
    if (_currentToken == null) {
      state = state.copyWith(error: 'No active connection attempt found.');
      return;
    }
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final session = await _service.getSession(_currentToken!);
      if (session != null) {
        await _repo.setSessionKey(session.key);
        await _repo.setUsername(session.name);
        state = state.copyWith(
          isConnected: true,
          username: session.name,
          isConnecting: false,
          hasPendingToken: false,
        );
      } else {
        state = state.copyWith(isConnecting: false, hasPendingToken: false, error: 'Failed to get session. Did you approve in the browser?');
      }
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e.toString());
    }
  }

  Future<void> disconnect() async {
    await _repo.setSessionKey(null);
    await _repo.setUsername(null);
    state = LastfmState();
  }
}
