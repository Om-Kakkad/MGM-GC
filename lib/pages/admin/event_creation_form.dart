import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class EventCreationForm extends StatefulWidget {
  const EventCreationForm({Key? key}) : super(key: key);

  @override
  _EventCreationFormState createState() => _EventCreationFormState();
}

class _EventCreationFormState extends State<EventCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _prizeDetailsController = TextEditingController();
  final TextEditingController _customRulesController = TextEditingController();

  // Form values
  String _eventType = 'League';
  String _scoringType = 'Stableford';
  String _tournamentFormat = 'Knockout';
  String _bracketType = 'Single Elimination';

  // Selected dates
  final List<DateTime> _selectedDates = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _prizeDetailsController.dispose();
    _customRulesController.dispose();
    super.dispose();
  }

  // Method to show date picker and add date
  Future<void> _addDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null && !_selectedDates.contains(picked)) {
      setState(() {
        _selectedDates.add(picked);
        // Sort dates
        _selectedDates.sort((a, b) => a.compareTo(b));
      });
    }
  }

  // Method to remove a date
  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.remove(date);
    });
  }

  // Submit event to Firestore
  Future<void> _submitEvent() async {
    if (_formKey.currentState!.validate() && _selectedDates.isNotEmpty) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Create base event data
        Map<String, dynamic> eventData = {
          'eventName': _nameController.text,
          'eventDescription': _descriptionController.text,
          'eventType': _eventType,
          'eventDates':
              _selectedDates.map((date) => Timestamp.fromDate(date)).toList(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Add event-specific fields based on event type
        if (_eventType == 'League') {
          eventData['scoringType'] = _scoringType;
        } else {
          eventData['tournamentFormat'] = _tournamentFormat;
          eventData['bracketType'] = _bracketType;
          eventData['prizeDetails'] = _prizeDetailsController.text;
          eventData['customRules'] = _customRulesController.text;
        }

        // Save to Firestore
        DocumentReference docRef = await _firestore
            .collection('events')
            .add(eventData);

        // Add the auto-generated ID to the document
        await docRef.update({'eventID': docRef.id});

        setState(() {
          _isLoading = false;
        });

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully!')),
          );

          // Clear form
          _nameController.clear();
          _descriptionController.clear();
          _prizeDetailsController.clear();
          _customRulesController.clear();
          setState(() {
            _selectedDates.clear();
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating event: $e')));
        }
      }
    } else if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one date')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create New Event',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Event Type Selection'),
              const SizedBox(height: 10),

              // Event Type
              _buildDropdown(
                label: 'Event Type',
                value: _eventType,
                items: const [
                  DropdownMenuItem(value: 'League', child: Text('League')),
                  DropdownMenuItem(
                    value: 'Custom Tournament',
                    child: Text('Custom Tournament'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _eventType = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('Common Event Details'),
              const SizedBox(height: 10),

              // Event Name
              _buildTextField(
                controller: _nameController,
                label: 'Event Name',
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please enter an event name'
                            : null,
              ),
              const SizedBox(height: 15),

              // Event Description
              _buildTextField(
                controller: _descriptionController,
                label: 'Event Description',
                maxLines: 3,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please enter an event description'
                            : null,
              ),
              const SizedBox(height: 20),

              // Event Dates
              Text(
                'Event Dates',
                style: GoogleFonts.raleway(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _addDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Add Date'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0D6EFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _selectedDates.isEmpty
                  ? const Text('No dates selected yet')
                  : Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children:
                        _selectedDates.map((date) {
                          return Chip(
                            label: Text(
                              DateFormat('MMM dd, yyyy').format(date),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeDate(date),
                            backgroundColor: const Color(0xffF7F7F9),
                          );
                        }).toList(),
                  ),
              const SizedBox(height: 25),

              // Conditional fields based on event type
              if (_eventType == 'League') ...[
                _buildSectionTitle('League-Specific Details'),
                const SizedBox(height: 10),

                _buildDropdown(
                  label: 'Scoring Type',
                  value: _scoringType,
                  items: const [
                    DropdownMenuItem(
                      value: 'Stableford',
                      child: Text('Stableford'),
                    ),
                    DropdownMenuItem(
                      value: 'Matchplay',
                      child: Text('Matchplay'),
                    ),
                    DropdownMenuItem(
                      value: 'Normal Score Input',
                      child: Text('Normal Score Input'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _scoringType = value!;
                    });
                  },
                ),
              ] else ...[
                _buildSectionTitle('Tournament-Specific Details'),
                const SizedBox(height: 10),

                // Tournament Format
                _buildDropdown(
                  label: 'Tournament Format',
                  value: _tournamentFormat,
                  items: const [
                    DropdownMenuItem(
                      value: 'Knockout',
                      child: Text('Knockout'),
                    ),
                    DropdownMenuItem(
                      value: 'Round-Robin',
                      child: Text('Round-Robin'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _tournamentFormat = value!;
                    });
                  },
                ),
                const SizedBox(height: 15),

                // Bracket Type
                _buildDropdown(
                  label: 'Bracket Type',
                  value: _bracketType,
                  items: const [
                    DropdownMenuItem(
                      value: 'Single Elimination',
                      child: Text('Single Elimination'),
                    ),
                    DropdownMenuItem(
                      value: 'Double Elimination',
                      child: Text('Double Elimination'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _bracketType = value!;
                    });
                  },
                ),
                const SizedBox(height: 15),

                // Prize Details
                _buildTextField(
                  controller: _prizeDetailsController,
                  label: 'Prize Details',
                ),
                const SizedBox(height: 15),

                // Custom Rules
                _buildTextField(
                  controller: _customRulesController,
                  label: 'Custom Rules',
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0D6EFD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            "Create Event",
                            style: GoogleFonts.raleway(
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.raleway(
        textStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}
