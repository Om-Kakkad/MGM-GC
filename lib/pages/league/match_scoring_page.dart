import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class MatchScoringPage extends StatefulWidget {
  const MatchScoringPage({super.key});

  @override
  State<MatchScoringPage> createState() => _MatchScoringPageState();
}

class _MatchScoringPageState extends State<MatchScoringPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  late String eventId;
  late String matchId;
  bool _authorized = false;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    eventId = args['eventId'];
    matchId = args['matchId'];
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    try {
      final doc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('matches')
          .doc(matchId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final players = Map<String, dynamic>.from(data['players'] ?? {});
        final uid = _authService.currentUser?.uid;
        final bool inMatch = players.values
            .whereType<List>()
            .any((list) => list.contains(uid));
        setState(() {
          _authorized = inMatch;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match Scoring')),
        body: const Center(
          child: Text('You are not authorized to score this match.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Match Scoring')),
      body: const Center(
        child: Text('Match scoring interface coming soon.'),
      ),
    );
  }
}
