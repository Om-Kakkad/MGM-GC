import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mgm_gc/models/sponsor.dart';
import 'package:mgm_gc/services/sponsor_service.dart';

class SponsorManagementPage extends StatefulWidget {
  const SponsorManagementPage({super.key});

  @override
  State<SponsorManagementPage> createState() => _SponsorManagementPageState();
}

class _SponsorManagementPageState extends State<SponsorManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SponsorService _sponsorService = SponsorService();

  bool _isLoading = false;
  String? _selectedEventId;
  List<DocumentSnapshot> _events = [];
  List<Sponsor> _sponsors = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('events').get();
      setState(() {
        _events = snapshot.docs;
        if (_events.isNotEmpty && _selectedEventId == null) {
          _selectedEventId = _events.first.id;
          _loadSponsors(_selectedEventId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
    }
  }

  Future<void> _loadSponsors(String eventId) async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('sponsors')
          .get();
      final sponsors = snapshot.docs
          .map((d) => Sponsor.fromMap(d.data(), d.id))
          .toList();
      setState(() {
        _sponsors = sponsors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sponsors: $e')),
      );
    }
  }

  Future<void> _deleteSponsor(String eventId, String sponsorId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Sponsor'),
            content: const Text('Are you sure you want to delete this sponsor?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _sponsorService.deleteSponsor(eventId, sponsorId);
      _loadSponsors(eventId);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting sponsor: $e')),
      );
    }
  }

  Future<void> _showSponsorDialog({Sponsor? sponsor}) async {
    final nameController =
        TextEditingController(text: sponsor?.sponsorName ?? '');
    final areaController = TextEditingController(text: sponsor?.area ?? '');
    final logoController = TextEditingController(text: sponsor?.logoUrl ?? '');
    final websiteController =
        TextEditingController(text: sponsor?.websiteUrl ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sponsor == null ? 'Add Sponsor' : 'Edit Sponsor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Area'),
              ),
              TextField(
                controller: logoController,
                decoration: const InputDecoration(labelText: 'Logo URL'),
              ),
              TextField(
                controller: websiteController,
                decoration: const InputDecoration(labelText: 'Website URL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true || _selectedEventId == null) return;

    final data = Sponsor(
      id: sponsor?.id,
      sponsorName: nameController.text,
      area: areaController.text,
      logoUrl: logoController.text,
      websiteUrl: websiteController.text,
    );

    setState(() => _isLoading = true);
    try {
      if (sponsor == null) {
        await _sponsorService.addSponsor(_selectedEventId!, data);
      } else {
        await _firestore
            .collection('events')
            .doc(_selectedEventId)
            .collection('sponsors')
            .doc(sponsor.id)
            .update(data.toMap());
      }
      _loadSponsors(_selectedEventId!);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sponsor: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sponsor Management',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _selectedEventId != null
                            ? () => _showSponsorDialog()
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Sponsor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0D6EFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Event',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    value: _selectedEventId,
                    items: _events
                        .map((e) {
                          final data = e.data() as Map<String, dynamic>;
                          final name =
                              data['eventName'] ?? data['name'] ?? 'Unnamed';
                          return DropdownMenuItem<String>(
                            value: e.id,
                            child: Text(name),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedEventId = value;
                        });
                        _loadSponsors(value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _selectedEventId == null
                      ? const Center(child: Text('Please select an event'))
                      : _sponsors.isEmpty
                          ? const Center(child: Text('No sponsors'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _sponsors.length,
                              itemBuilder: (context, index) {
                                final sponsor = _sponsors[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: ListTile(
                                    title: Text(sponsor.sponsorName),
                                    subtitle: Text(sponsor.area),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _showSponsorDialog(sponsor: sponsor),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => _deleteSponsor(
                                            _selectedEventId!,
                                            sponsor.id!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
