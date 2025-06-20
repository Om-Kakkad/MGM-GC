import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/tee_time_service.dart';

class SlotsManagementPage extends StatefulWidget {
  const SlotsManagementPage({super.key});

  @override
  State<SlotsManagementPage> createState() => _SlotsManagementPageState();
}

class _SlotsManagementPageState extends State<SlotsManagementPage> {
  final TeeTimeService _teeTimeService = TeeTimeService();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Slots Management',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _teeTimeService.getSlotsForDate(_selectedDate),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No slots for ${DateFormat.yMMMd().format(_selectedDate)}',
                style: GoogleFonts.raleway(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final time = (data['time'] as Timestamp).toDate();
              final blocked = data['blocked'] == true;
              final held = data['held'] == true;
              return ListTile(
                title: Text(DateFormat('hh:mm a').format(time)),
                subtitle: Row(
                  children: [
                    Chip(
                      label: Text(blocked ? 'Blocked' : 'Open'),
                      backgroundColor:
                          blocked ? Colors.red[200] : Colors.green[200],
                    ),
                    const SizedBox(width: 8),
                    if (held)
                      const Chip(
                        label: Text('Held'),
                        backgroundColor: Colors.orange,
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        blocked ? Icons.lock_open : Icons.lock,
                        color: blocked ? Colors.green : Colors.red,
                      ),
                      onPressed: () => _teeTimeService.blockSlot(doc.id, !blocked),
                    ),
                    IconButton(
                      icon: Icon(
                        held ? Icons.pause_circle : Icons.play_circle,
                        color: held ? Colors.orange : Colors.blue,
                      ),
                      onPressed: () => _teeTimeService.holdSlot(doc.id, !held),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
