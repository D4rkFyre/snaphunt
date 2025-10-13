// lib/models/game_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// -------------------------------
/// Game status (domain-level)
/// -------------------------------
enum GameStatus { waiting, started, finished }

extension GameStatusX on GameStatus {
  String get asString {
    switch (this) {
      case GameStatus.waiting:
        return 'waiting';
      case GameStatus.started:
        return 'started';
      case GameStatus.finished:
        return 'finished';
    }
  }

  static GameStatus fromString(String? raw) {
    // Back-compat + typo tolerance
    switch (raw) {
      case 'waiting':
        return GameStatus.waiting;
      case 'started':
      case 'active': // legacy alias
        return GameStatus.started;
      case 'finished':
      case 'completed': // legacy alias
        return GameStatus.finished;
      default:
        return GameStatus.waiting;
    }
  }
}

/// -------------------------------
/// Player entry
/// -------------------------------
class PlayerEntry {
  final String deviceId; // may be empty on legacy docs
  final String nickname;

  const PlayerEntry({required this.deviceId, required this.nickname});

  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'nickname': nickname,
  };

  factory PlayerEntry.fromMap(dynamic raw) {
    // Back-compat: if legacy string nickname, map deviceId -> ""
    if (raw is String) {
      return PlayerEntry(deviceId: "", nickname: raw);
    }
    if (raw is Map<String, dynamic>) {
      return PlayerEntry(
        deviceId: (raw['deviceId'] as String?) ?? "",
        nickname: (raw['nickname'] as String?) ?? "",
      );
    }
    // Fallback to empty entry to avoid crashes
    return const PlayerEntry(deviceId: "", nickname: "");
  }
}

/// -------------------------------
/// Game model
/// -------------------------------
class Game {
  final String id;
  final String joinCode;
  final GameStatus status;            // enum in-memory
  final Timestamp createdAt;

  /// Persistence / enforcement
  final String? hostDeviceId;         // null on legacy docs
  final List<String> playerDeviceIds; // [] on legacy docs
  final List<PlayerEntry> players;    // [{deviceId, nickname}] or legacy strings -> converted

  /// deviceId -> 'host' | 'player' (others ignored on read)
  final Map<String, String> roles;

  const Game({
    required this.id,
    required this.joinCode,
    required this.status,
    required this.createdAt,
    this.hostDeviceId,
    this.playerDeviceIds = const [],
    this.players = const [],
    this.roles = const {},
  });

  Game copyWith({
    String? id,
    String? joinCode,
    GameStatus? status,
    Timestamp? createdAt,
    String? hostDeviceId,
    List<String>? playerDeviceIds,
    List<PlayerEntry>? players,
    Map<String, String>? roles,
  }) {
    return Game(
      id: id ?? this.id,
      joinCode: joinCode ?? this.joinCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      hostDeviceId: hostDeviceId ?? this.hostDeviceId,
      playerDeviceIds: playerDeviceIds ?? this.playerDeviceIds,
      players: players ?? this.players,
      roles: roles ?? this.roles,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'joinCode': joinCode,
      'status': status.asString, // write as string for Firestore
      'createdAt': createdAt,
      if (hostDeviceId != null) 'hostDeviceId': hostDeviceId,
      'playerDeviceIds': playerDeviceIds,
      'players': players.map((p) => p.toMap()).toList(),
      if (roles.isNotEmpty) 'roles': roles,
    };
  }

  factory Game.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final rawPlayers = data['players'];

    // Parse players with back-compat support
    final parsedPlayers = <PlayerEntry>[];
    if (rawPlayers is List) {
      for (final e in rawPlayers) {
        parsedPlayers.add(PlayerEntry.fromMap(e));
      }
    }

    // Parse playerDeviceIds with a safe fallback
    final pdevIdsRaw = data['playerDeviceIds'];
    final parsedDeviceIds = <String>[];
    if (pdevIdsRaw is List) {
      for (final e in pdevIdsRaw) {
        if (e is String) parsedDeviceIds.add(e);
      }
    }

    // Parse roles map: { deviceId: 'host' | 'player' }
    final rawRoles = data['roles'];
    final parsedRoles = <String, String>{};
    if (rawRoles is Map<String, dynamic>) {
      rawRoles.forEach((k, v) {
        if (k is String && v is String) {
          // Only accept expected values; ignore anything else safely.
          if (v == 'host' || v == 'player') {
            parsedRoles[k] = v;
          }
        }
      });
    }

    final statusStr = ((data['status'] as String?) ?? 'waiting').trim().toLowerCase();

    return Game(
      id: id,
      joinCode: (data['joinCode'] as String?) ?? '',
      status: GameStatusX.fromString(statusStr),
      createdAt: createdAt is Timestamp ? createdAt : Timestamp.now(),
      hostDeviceId: data['hostDeviceId'] as String?, // null on legacy
      playerDeviceIds: parsedDeviceIds,
      players: parsedPlayers,
      roles: parsedRoles,
    );
  }

  /// -------------------------------
  /// Convenience getters
  /// -------------------------------

  /// Returns true if this device is the host of the game.
  bool isHost(String deviceId) =>
      hostDeviceId == deviceId || roles[deviceId] == 'host';

  /// Returns only the non-host players.
  Iterable<PlayerEntry> nonHostPlayers() {
    if (hostDeviceId == null) return players;
    return players.where((p) => p.deviceId != hostDeviceId);
  }
}
