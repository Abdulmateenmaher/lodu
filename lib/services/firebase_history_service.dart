import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_record.dart';

class MatchRecordFirestore {
  final String id;
  final String winnerLabel;
  final List<String> playerNames;
  final List<bool> playerIsAI;
  final DateTime playedAt;
  final int stars;
  final String statusText;

  MatchRecordFirestore({
    required this.id,
    required this.winnerLabel,
    required this.playerNames,
    required this.playerIsAI,
    required this.playedAt,
    required this.stars,
    required this.statusText,
  });

  factory MatchRecordFirestore.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MatchRecordFirestore(
      id: doc.id,
      winnerLabel: d['winnerLabel'] ?? '',
      playerNames: List<String>.from(d['playerNames'] ?? const []),
      playerIsAI: List<bool>.from(d['playerIsAI'] ?? const []),
      playedAt: (d['playedAt'] as Timestamp?)?.toDate() ??
          DateTime.tryParse(d['playedAt']?.toString() ?? '') ??
          DateTime.now(),
      stars: d['stars'] ?? 1,
      statusText: d['statusText'] ?? '',
    );
  }

  MatchRecord toMatchRecord() => MatchRecord(
        winnerLabel: winnerLabel,
        playerNames: playerNames,
        playerIsAI: playerIsAI,
        playedAt: playedAt,
        stars: stars,
        statusText: statusText,
      );

  Map<String, dynamic> toMap() => {
        'winnerLabel': winnerLabel,
        'playerNames': playerNames,
        'playerIsAI': playerIsAI,
        'playedAt': Timestamp.fromDate(playedAt),
        'stars': stars,
        'statusText': statusText,
      };
}

class FirebaseHistoryService {
  static FirebaseHistoryService? _instance;
  factory FirebaseHistoryService() {
    _instance ??= FirebaseHistoryService._();
    return _instance!;
  }
  FirebaseHistoryService._();

  FirebaseFirestore? _db;
  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  CollectionReference<Map<String, dynamic>> _userMatchesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('matches');
  }

  Future<void> saveMatchRecord(String uid, MatchRecord record) async {
    await _userMatchesRef(uid).add(record.toJson());
  }

  Future<List<MatchRecord>> loadMatchRecords(String uid) async {
    try {
      final snapshot = await _userMatchesRef(uid)
          .orderBy('playedAt', descending: true)
          .limit(200)
          .get();

      final records = <MatchRecord>[];
      for (final doc in snapshot.docs) {
        try {
          final rec = MatchRecordFirestore.fromDoc(doc);
          records.add(rec.toMatchRecord());
        } catch (_) {
          continue;
        }
      }
      return records;
    } catch (e) {
      return <MatchRecord>[];
    }
  }

  Future<void> deleteMatchRecord(String uid, String matchId) async {
    await _userMatchesRef(uid).doc(matchId).delete();
  }

  Future<void> clearAllHistory(String uid) async {
    final snapshot = await _userMatchesRef(uid).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<int> getHistoryCount(String uid) async {
    final snapshot = await _userMatchesRef(uid).get();
    return snapshot.size;
  }
}
