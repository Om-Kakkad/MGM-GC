import 'package:flutter/material.dart';
import '../../services/aggregate_score_service.dart';

class AggregateScoresPage extends StatefulWidget {
  const AggregateScoresPage({super.key});

  @override
  State<AggregateScoresPage> createState() => _AggregateScoresPageState();
}

class _AggregateScoresPageState extends State<AggregateScoresPage> {
  final AggregateScoreService _service = AggregateScoreService();
  late Future<List<Map<String, dynamic>>> _scoresFuture;

  @override
  void initState() {
    super.initState();
    _scoresFuture = _service.getAggregateScores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aggregate Scores')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _scoresFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load scores'));
          }

          final scores = snapshot.data ?? [];
          if (scores.isEmpty) {
            return const Center(child: Text('No scores found'));
          }

          return ListView.builder(
            itemCount: scores.length,
            itemBuilder: (context, index) {
              final team = scores[index];
              final name = team['teamName'] ?? 'Team ${index + 1}';
              final total = team['total'] ?? team['score'] ?? 0;
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(name),
                trailing: Text(total.toString()),
              );
            },
          );
        },
      ),
    );
  }
}
