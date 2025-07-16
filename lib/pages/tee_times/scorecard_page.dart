import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mgm_gc/models/booking_model.dart';
import 'package:mgm_gc/models/scorecard_model.dart';
import 'package:mgm_gc/services/scorecard_service.dart';

class ScorecardPage extends StatefulWidget {
  const ScorecardPage({super.key});

  @override
  State<ScorecardPage> createState() => _ScorecardPageState();
}

class _ScorecardPageState extends State<ScorecardPage> {
  bool _isLoading = true;
  late BookingModel _booking;
  ScorecardModel? _scorecard;
  late ScorecardService _scorecardService;
  final List<int> _pars = [
    3,
    3,
    4,
    4,
    5,
    3,
    5,
    4,
    3,
    4,
    5,
    3,
    5,
    3,
    4,
    3,
    4,
    4,
  ]; // Default pars
  final List<int> _strokeIndexes = [
    18,
    8,
    2,
    10,
    4,
    14,
    6,
    16,
    12,
    9,
    1,
    13,
    3,
    15,
    11,
    17,
    7,
    5,
  ]; // Default indexes

  // Controllers for hole scores
  final Map<String, Map<int, TextEditingController>> _controllers = {};
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scorecardService = Provider.of<ScorecardService>(context);
    _loadBookingAndScorecard();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var playerControllers in _controllers.values) {
      for (var controller in playerControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadBookingAndScorecard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _booking = args['booking'] as BookingModel;

      try {
        // Try to get or create scorecard normally
        _scorecard = await _scorecardService.getOrCreateScorecard(_booking);
      } catch (firestoreError) {
        // If Firestore has permission issues, use debug method (for development only)
        print('Using debug scorecard due to error: $firestoreError');
        _scorecard = await _scorecardService.createDebugScorecard(_booking);
      }

      // Setup controllers for each player and hole
      _setupControllers();
    } catch (e) {
      print('Error in scorecard loading: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading scorecard: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupControllers() {
    if (_scorecard == null) return;

    _controllers.clear();

    // Create controllers for each player and hole
    for (var entry in _scorecard!.playerScores.entries) {
      final playerId = entry.key;
      final playerScores = entry.value;

      _controllers[playerId] = {};

      // Create controllers for all 18 holes
      for (int i = 1; i <= 18; i++) {
        final holeKey = i.toString();
        // Initialize with existing score or empty
        final score = playerScores.holeScores[holeKey];
        _controllers[playerId]![i] = TextEditingController(
          text: score != null ? score.toString() : '',
        );
      }
    }
  }

  Future<void> _saveScores() async {
    if (_scorecard == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // For each player, save their scores
      for (var entry in _controllers.entries) {
        final playerId = entry.key;
        final playerControllers = entry.value;

        Map<String, int> holeScores = {};

        // Collect non-empty scores from controllers
        for (int i = 1; i <= 18; i++) {
          final controller = playerControllers[i];
          if (controller != null && controller.text.isNotEmpty) {
            try {
              final score = int.parse(controller.text);
              if (score > 0) {
                holeScores[i.toString()] = score;
              }
            } catch (e) {
              // Skip invalid scores
            }
          }
        }

        // Only update if there are scores to save
        if (holeScores.isNotEmpty) {
          await _scorecardService.updatePlayerScore(
            _scorecard!.id,
            playerId,
            holeScores,
          );
        }
      }

      // Reload scorecard to get updated data
      final updated = await _scorecardService.getScorecardById(_scorecard!.id);
      if (updated != null) {
        setState(() {
          _scorecard = updated;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scores saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving scores: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _finishRound() async {
    if (_scorecard == null) return;

    // First save any unsaved scores
    await _saveScores();

    setState(() {
      _isSaving = true;
    });

    try {
      // Complete the scorecard and process handicaps
      final success = await _scorecardService.completeScorecard(_scorecard!.id);

      if (success) {
        // Reload the scorecard to get updated data
        final updated = await _scorecardService.getScorecardById(
          _scorecard!.id,
        );
        if (updated != null) {
          setState(() {
            _scorecard = updated;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Round completed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete round')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error completing round: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scorecard'),
        actions: [
          if (_scorecard != null && !_scorecard!.isCompleted)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveScores,
              tooltip: 'Save Scores',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildScorecardContent(),
      bottomNavigationBar:
          _scorecard != null && !_scorecard!.isCompleted
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _finishRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child:
                        _isSaving
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text('FINISH ROUND'),
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildScorecardContent() {
    if (_scorecard == null) {
      return const Center(child: Text('Could not load scorecard'));
    }

    return Column(
      children: [_buildHeader(), Expanded(child: _buildScorecardTable())],
    );
  }

  Widget _buildHeader() {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Determine if this is a 9-hole round by checking the first player
    bool isNineHoleRound = false;
    if (_scorecard!.playerScores.isNotEmpty) {
      final firstPlayer = _scorecard!.playerScores.entries.first.value;
      isNineHoleRound = firstPlayer.isNineHoleRound;
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _scorecard!.courseName ?? 'Golf Course',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                Chip(
                  label: Text(
                    isNineHoleRound ? '9-HOLE ROUND' : '18-HOLE ROUND',
                  ),
                  backgroundColor: Colors.blue.shade100,
                  labelStyle: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              'Date: ${dateFormat.format(_booking.startTime)}',
              style: const TextStyle(fontSize: 14.0),
            ),
            Text(
              'Time: ${timeFormat.format(_booking.startTime)} - ${timeFormat.format(_booking.endTime)}',
              style: const TextStyle(fontSize: 14.0),
            ),
            if (_scorecard!.isCompleted)
              Chip(
                label: const Text('COMPLETED'),
                backgroundColor: Colors.green.shade100,
                labelStyle: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScorecardTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFrontNine(),
              const SizedBox(height: 24.0),
              _buildBackNine(),
              const SizedBox(height: 24.0),
              _buildTotals(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontNine() {
    return _buildHoleSection(1, 9, 'Front Nine');
  }

  Widget _buildBackNine() {
    return _buildHoleSection(10, 18, 'Back Nine');
  }

  Widget _buildHoleSection(int startHole, int endHole, String title) {
    if (_scorecard!.playerScores.isEmpty) {
      return const Center(child: Text('No players found'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultColumnWidth: const FixedColumnWidth(60.0),
          children: [
            // Header row with hole numbers
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                const TableCell(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4.0,
                    ),
                    child: Text(
                      'Player',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ...List.generate(endHole - startHole + 1, (index) {
                  final holeNum = startHole + index;
                  return TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '$holeNum',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
              ],
            ),
            // Par row
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: [
                const TableCell(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4.0,
                    ),
                    child: Text(
                      'Par',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ...List.generate(endHole - startHole + 1, (index) {
                  final holeNum = startHole + index;
                  final par = holeNum <= _pars.length ? _pars[holeNum - 1] : 4;
                  return TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('$par', textAlign: TextAlign.center),
                    ),
                  );
                }),
              ],
            ),
            // Index row
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: [
                const TableCell(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4.0,
                    ),
                    child: Text(
                      'S.I.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ...List.generate(endHole - startHole + 1, (index) {
                  final holeNum = startHole + index;
                  final strokeIdx =
                      holeNum <= _strokeIndexes.length
                          ? _strokeIndexes[holeNum - 1]
                          : holeNum;
                  return TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '$strokeIdx',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            // Player score rows
            ..._scorecard!.playerScores.entries.map((entry) {
              final playerId = entry.key;
              final playerCard = entry.value;

              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      child: Text(
                        _truncatePlayerName(playerCard.playerName),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ...List.generate(endHole - startHole + 1, (index) {
                    final holeNum = startHole + index;
                    return TableCell(
                      child: _buildScoreInput(playerId, holeNum, playerCard),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreInput(
    String playerId,
    int holeNum,
    PlayerScorecard playerCard,
  ) {
    final controller = _controllers[playerId]?[holeNum];
    if (controller == null) return const SizedBox();

    if (_scorecard!.isCompleted) {
      // Display score as text for completed scorecards
      final score = playerCard.holeScores[holeNum.toString()];
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        alignment: Alignment.center,
        child: Text(
          score != null ? score.toString() : '-',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getScoreColor(score, _pars[holeNum - 1]),
          ),
        ),
      );
    } else {
      // Editable input for active scorecards
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
        child: TextFormField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 4.0,
            ),
            border: OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLength: 2,
          onTap:
              () =>
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  ),
        ),
      );
    }
  }

  Widget _buildTotals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Totals',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: const [
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Player',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Front',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Back',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            ..._scorecard!.playerScores.entries.map((entry) {
              final playerCard = entry.value;

              // Calculate front nine total
              int frontTotal = 0;
              int frontCount = 0;
              for (int i = 1; i <= 9; i++) {
                final score = playerCard.holeScores[i.toString()];
                if (score != null) {
                  frontTotal += score;
                  frontCount++;
                }
              }

              // Calculate back nine total
              int backTotal = 0;
              int backCount = 0;
              for (int i = 10; i <= 18; i++) {
                final score = playerCard.holeScores[i.toString()];
                if (score != null) {
                  backTotal += score;
                  backCount++;
                }
              }

              final totalScore = frontTotal + backTotal;

              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        playerCard.playerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        frontCount > 0 ? '$frontTotal' : '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        backCount > 0 ? '$backTotal' : '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        (frontCount + backCount) > 0 ? '$totalScore' : '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        if (_scorecard!.isCompleted) ...[
          const SizedBox(height: 24.0),
          _buildHandicapResults(),
        ],
      ],
    );
  }

  Widget _buildHandicapResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Handicap Results',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: const [
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Player',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Handicap',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Adjusted',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Differential',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            ..._scorecard!.playerScores.entries.map((entry) {
              final playerCard = entry.value;

              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        playerCard.playerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        playerCard.courseHandicap != null
                            ? '${playerCard.courseHandicap}'
                            : 'N/A',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        playerCard.adjustedGrossScore != null
                            ? '${playerCard.adjustedGrossScore}'
                            : 'N/A',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        playerCard.scoreDifferential != null
                            ? playerCard.scoreDifferential!.toStringAsFixed(1)
                            : 'N/A',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '* Note: Players must complete at least 3 rounds for a Handicap Index to be calculated',
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4.0),

              // Add note about 9-hole rounds if applicable
              if (_scorecard!.playerScores.isNotEmpty &&
                  _scorecard!.playerScores.entries.first.value.isNineHoleRound)
                Text(
                  '* 9-hole scores are adjusted according to World Handicap System rules for handicap calculation',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32.0), // Add space at the bottom
      ],
    );
  }

  String _truncatePlayerName(String name) {
    if (name.length <= 10) return name;
    return '${name.substring(0, 8)}...';
  }

  Color _getScoreColor(int? score, int par) {
    if (score == null) return Colors.black;

    if (score < par - 1) return Colors.purple; // Eagle or better
    if (score == par - 1) return Colors.red; // Birdie
    if (score == par) return Colors.black; // Par
    if (score == par + 1) return Colors.blue; // Bogey
    return Colors.green.shade900; // Double bogey or worse
  }
}
