import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mgm_gc/models/booking_model.dart';
import 'package:mgm_gc/services/tee_time_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerSelectionDialog extends StatefulWidget {
  final List<PlayerInfo> initialPlayers;

  const PlayerSelectionDialog({super.key, this.initialPlayers = const []});

  @override
  _PlayerSelectionDialogState createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualNameController = TextEditingController();
  final FocusNode _manualNameFocus = FocusNode();
  List<PlayerInfo> _selectedPlayers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _selectedPlayers = List.from(widget.initialPlayers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualNameController.dispose();
    _manualNameFocus.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final teeTimeService = Provider.of<TeeTimeService>(context, listen: false);
    final results = await teeTimeService.searchUsers(query);

    // Filter out users that are already selected
    final filteredResults =
        results.where((user) {
          return !_selectedPlayers.any(
            (player) => player.isRegistered && player.userId == user['id'],
          );
        }).toList();

    setState(() {
      _searchResults = filteredResults;
      _isSearching = false;
    });
  }

  void _addRegisteredPlayer(Map<String, dynamic> userData) {
    // Create PlayerInfo from user data
    final newPlayer = PlayerInfo(
      name: userData['name'],
      userId: userData['id'],
      isRegistered: true,
    );

    // Add to selected players if not already present
    if (!_selectedPlayers.any(
      (player) => player.isRegistered && player.userId == userData['id'],
    )) {
      setState(() {
        _selectedPlayers.add(newPlayer);
        _searchController.clear();
        _searchResults = [];
      });
    }
  }

  void _addManualPlayer() {
    final name = _manualNameController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _selectedPlayers.add(PlayerInfo(name: name, isRegistered: false));
        _manualNameController.clear();
      });
      _manualNameFocus.requestFocus();
    }
  }

  void _removePlayer(int index) {
    setState(() {
      _selectedPlayers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Players',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Search for registered users
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for users',
                hintText: 'Enter email or name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                if (value.length >= 3) {
                  _searchUsers(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),

            // Search results
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      title: Text(user['name']),
                      subtitle: Text(user['email']),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _addRegisteredPlayer(user),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            const Divider(),

            // Add non-registered player
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualNameController,
                    focusNode: _manualNameFocus,
                    decoration: InputDecoration(
                      labelText: 'Add player by name',
                      hintText: 'Enter player name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _addManualPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addManualPlayer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Selected players list
            const Text(
              'Selected Players:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_selectedPlayers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No players selected'),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _selectedPlayers.length,
                  itemBuilder: (context, index) {
                    final player = _selectedPlayers[index];
                    return ListTile(
                      leading: Icon(
                        player.isRegistered
                            ? Icons.account_circle
                            : Icons.person_outline,
                        color: player.isRegistered ? Colors.blue : Colors.grey,
                      ),
                      title: Text(player.name),
                      subtitle:
                          player.isRegistered
                              ? const Text(
                                'Registered User',
                                style: TextStyle(color: Colors.blue),
                              )
                              : const Text('Guest Player'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removePlayer(index),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedPlayers),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
