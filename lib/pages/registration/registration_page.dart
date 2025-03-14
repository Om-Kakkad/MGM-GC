import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mgm_gc/models/user_model.dart';
import 'package:mgm_gc/services/auth_service.dart';

class RegistrationPage extends StatefulWidget {
  final User user;

  const RegistrationPage({Key? key, required this.user}) : super(key: key);

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Form fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _handicapController = TextEditingController();
  final TextEditingController _membershipIdController = TextEditingController();
  final TextEditingController _teamPasswordController = TextEditingController();

  // Form values
  String _selectedGender = '';
  bool _isMember = false;
  bool _playingInLeague = false;
  String? _selectedTeamId;
  DateTime? _selectedDate;

  // Teams data
  Stream<List<Team>>? _teamsStream;

  @override
  void initState() {
    super.initState();
    _teamsStream = _authService.getTeams();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _handicapController.dispose();
    _membershipIdController.dispose();
    _teamPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // Default to 18 years ago
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      // Create Golf Details
      final golfDetails = GolfDetails(
        handicap:
            _handicapController.text.isEmpty
                ? null
                : double.tryParse(_handicapController.text),
        isMember: _isMember,
        membershipId: _isMember ? _membershipIdController.text : null,
        playingInLeague: _playingInLeague,
        teamId: _playingInLeague ? _selectedTeamId : null,
        teamName:
            _playingInLeague && _selectedTeamId != null
                ? await _getTeamName(_selectedTeamId!)
                : null,
      );

      // Create User Model
      final userModel = UserModel(
        uid: widget.user.uid,
        email: widget.user.email ?? '',
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        dateOfBirth: _selectedDate ?? DateTime.now(),
        gender: _selectedGender,
        phoneNumber: _phoneController.text,
        golfDetails: golfDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user to Firestore
      await _authService.saveUserProfile(
        user: userModel,
        context: context,
        teamPassword: _playingInLeague ? _teamPasswordController.text : null,
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _getTeamName(String teamId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .get();
      return doc.data()?['name'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Complete Your Profile',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Basic Profile Details'),
                const SizedBox(height: 16),

                // First Name and Last Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Please enter your first name'
                                    : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Please enter your last name'
                                    : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date of Birth
                _buildTextField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please select your date of birth'
                              : null,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                const SizedBox(height: 16),

                // Gender
                _buildDropdown(
                  label: 'Gender',
                  value: _selectedGender.isEmpty ? null : _selectedGender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                    DropdownMenuItem(
                      value: 'Prefer not to say',
                      child: Text('Prefer not to say'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value ?? '';
                    });
                  },
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please select your gender'
                              : null,
                ),
                const SizedBox(height: 16),

                // Phone Number
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your phone number'
                              : null,
                ),
                const SizedBox(height: 32),

                // GOLF DETAILS SECTION
                _sectionTitle('Golf-Specific Details'),
                const SizedBox(height: 16),

                // Handicap
                _buildTextField(
                  controller: _handicapController,
                  label: 'Existing Handicap (optional)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Membership
                _buildCheckbox(
                  value: _isMember,
                  title: 'I am a Member',
                  onChanged: (value) {
                    setState(() {
                      _isMember = value ?? false;
                      if (!_isMember) {
                        _membershipIdController.clear();
                      }
                    });
                  },
                ),

                // Membership ID (conditional)
                if (_isMember) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _membershipIdController,
                    label: 'Membership ID',
                    validator:
                        (value) =>
                            _isMember && (value == null || value.isEmpty)
                                ? 'Please enter your membership ID'
                                : null,
                  ),
                ],
                const SizedBox(height: 16),

                // League
                _buildCheckbox(
                  value: _playingInLeague,
                  title: 'Playing in League',
                  onChanged: (value) {
                    setState(() {
                      _playingInLeague = value ?? false;
                      if (!_playingInLeague) {
                        _selectedTeamId = null;
                        _teamPasswordController.clear();
                      }
                    });
                  },
                ),

                // Team selection (conditional)
                if (_playingInLeague) ...[
                  const SizedBox(height: 16),
                  _buildStreamDropdown<Team>(
                    label: 'Select Your Team',
                    stream: _teamsStream,
                    itemBuilder:
                        (team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(team.name),
                        ),
                    selectedValue: _selectedTeamId,
                    onChanged: (value) {
                      setState(() {
                        _selectedTeamId = value;
                      });
                    },
                    validator:
                        (value) =>
                            _playingInLeague && (value == null || value.isEmpty)
                                ? 'Please select a team'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  // Team password
                  _buildTextField(
                    controller: _teamPasswordController,
                    label: 'Team Password',
                    obscureText: true,
                    validator:
                        (value) =>
                            _playingInLeague && (value == null || value.isEmpty)
                                ? 'Please enter team password'
                                : null,
                  ),
                ],

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0D6EFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _submitForm,
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : Text(
                              "Complete Registration",
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
      ),
    );
  }

  Widget _sectionTitle(String title) {
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
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
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
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required String? Function(T?)? validator,
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
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildStreamDropdown<T>({
    required String label,
    required Stream<List<T>>? stream,
    required DropdownMenuItem<String> Function(T) itemBuilder,
    required String? selectedValue,
    required void Function(String?) onChanged,
    required String? Function(String?)? validator,
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
        StreamBuilder<List<T>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Text('Error loading teams');
            }

            final items = snapshot.data ?? [];
            final dropdownItems = items.map(itemBuilder).toList();

            // Add a default "Select" option
            dropdownItems.insert(
              0,
              const DropdownMenuItem(value: '', child: Text('Select a team')),
            );

            return DropdownButtonFormField<String>(
              value: selectedValue,
              items: dropdownItems,
              onChanged: onChanged,
              validator: validator,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xffF7F7F9),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              isExpanded: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String title,
    required void Function(bool?) onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: GoogleFonts.raleway(
          textStyle: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
