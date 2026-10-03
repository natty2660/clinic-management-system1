import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReceptionScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;

  const ReceptionScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // OPD Registration Form State
  final _opdFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+251 9'); // Default Ethiopian dial code +251
  final _dobController = TextEditingController(text: '1995-05-15');
  final _ageController = TextEditingController(text: '31');
  final _allergiesController = TextEditingController(text: 'None known');
  final _emergencyController = TextEditingController();
  String _gender = 'female';
  String _bloodGroup = 'O+';
  String _department = 'General OPD';
  String _doctorName = 'Dr. Sarah Chen, MD';

  // Section 4: Advance Patient Deposit (OPD intake)
  bool _collectAdvanceDeposit = false;
  double _depositAmount = 1000.0;
  String _depositMethod = 'cash';
  final _depositRefController = TextEditingController();

  // Inpatient (IPD) Admission Form State (Command 2)
  final _ipdFormKey = GlobalKey<FormState>();
  final _ipdPatientNameController = TextEditingController();
  final _ipdDiagnosisController = TextEditingController(text: 'Acute Internal Medicine Care');
  final _ipdEmergencyPhoneController = TextEditingController(text: '+251 9');
  String _wardName = 'General Ward A';
  String _bedNumber = 'BED-04';

  // Command 2: 4 Fixed Preset Prices + 1 Blank Box for Cashier Agreement
  final List<double> _fixedIpdPrices = [2000.0, 2500.0, 3000.0, 5000.0];
  double _ipdDepositAmount = 3000.0;
  final _ipdCustomAgreedController = TextEditingController(); // Blank box
  bool _isCustomAgreed = false;

  List<Visit> _queueVisits = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadQueue();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    _emergencyController.dispose();
    _depositRefController.dispose();

    _ipdPatientNameController.dispose();
    _ipdDiagnosisController.dispose();
    _ipdEmergencyPhoneController.dispose();
    _ipdCustomAgreedController.dispose();
    super.dispose();
  }

  void _loadQueue() async {
    final visits = await ApiService().getVisits();
    if (mounted) {
      setState(() {
        _queueVisits = visits;
      });
    }
  }

  // Handle OPD Registration & Ticket Issuance
  void _submitOpdRegistration() async {
    if (!_opdFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final patient = await ApiService().registerPatient(
        name: _nameController.text,
        gender: _gender,
        dob: _dobController.text,
        age: int.tryParse(_ageController.text) ?? 30,
        phone: _phoneController.text,
        bloodGroup: _bloodGroup,
        allergies: _allergiesController.text,
        emergencyContact: _emergencyController.text,
        initialDepositAmount: _collectAdvanceDeposit ? _depositAmount : 0.0,
        depositPaymentMethod: _depositMethod,
        depositReference: _depositRefController.text,
      );

      final visit = await ApiService().enqueuePatient(
        patient: patient,
        department: _department,
        doctorName: _doctorName,
        fee: 350.0,
      );

      _loadQueue();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text(
              'Enqueued ${patient.name} -> Queue #${visit.queueNumber} (${patient.mrn})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );

        // Reset form
        _nameController.clear();
        _phoneController.text = '+251 9';
        setState(() {
          _collectAdvanceDeposit = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Handle Command 2: Inpatient Admission with Blank Box Cashier Agreement
  void _submitIpdAdmission() async {
    if (!_ipdFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create patient record for admission
      final patient = await ApiService().registerPatient(
        name: _ipdPatientNameController.text,
        gender: 'female',
        dob: '1990-01-01',
        age: 36,
        phone: _ipdEmergencyPhoneController.text,
        bloodGroup: 'O+',
        initialDepositAmount: _ipdDepositAmount,
      );

      final admission = await ApiService().admitPatient(
        patient: patient,
        wardName: _wardName,
        bedNumber: _bedNumber,
        doctorName: 'Dr. Sarah Chen, MD',
        provisionalDiagnosis: _ipdDiagnosisController.text,
        initialDeposit: _ipdDepositAmount,
        isCustomAgreed: _isCustomAgreed,
        emergencyPhone: _ipdEmergencyPhoneController.text,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF2DD4BF)),
                SizedBox(width: 8),
                Text('Inpatient Admitted Successfully', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admission Number: ${admission.admissionNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Patient: ${admission.patientName} (${admission.patientMrn})', style: const TextStyle(color: Color(0xFF94A3B8))),
                Text('Bed: ${admission.bedNumber} - ${admission.wardName}', style: const TextStyle(color: Color(0xFF94A3B8))),
                const Divider(color: Color(0xFF334155)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCustomAgreed ? 'Agreed Deposit (Blank Box):' : 'Mandatory IPD Deposit:',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                    ),
                    Text(
                      ApiService.formatCurrency(admission.initialDeposit),
                      style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
                Text('Receipt: ${admission.depositReceiptNumber}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close & Print Slip', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        // Reset
        _ipdPatientNameController.clear();
        _ipdCustomAgreedController.clear();
        setState(() {
          _isCustomAgreed = false;
          _ipdDepositAmount = 3000.0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF14B8A6)),
            const SizedBox(width: 8),
            const Text(
              'Reception & Cashier Workstation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0F766E)),
              ),
              child: Text(
                'Op: ${widget.currentUser.name} (${widget.currentUser.username})',
                style: const TextStyle(fontSize: 10, color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out to Login Gate',
            onPressed: widget.onLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF14B8A6),
          labelColor: const Color(0xFF14B8A6),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.person_add_alt_1, size: 18), text: 'OPD Intake & Presets'),
            Tab(icon: Icon(Icons.hotel_rounded, size: 18), text: 'IPD Ward Admission'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Active OPD Queue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpdRegistrationTab(),
          _buildIpdAdmissionTab(),
          _buildQueueTab(),
        ],
      ),
    );
  }

  // --- TAB 1: OPD Registration with Default Phone Code +251 ---
  Widget _buildOpdRegistrationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _opdFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Demographics
                _buildSectionHeader('1. Patient Demographics & Identification (Default Dial Code: +251 🇪🇹)'),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('Full Patient Name *', 'e.g. Almaz Bekele'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Gender
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _gender,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Gender', ''),
                                items: const [
                                  DropdownMenuItem(value: 'female', child: Text('Female')),
                                  DropdownMenuItem(value: 'male', child: Text('Male')),
                                  DropdownMenuItem(value: 'other', child: Text('Other')),
                                ],
                                onChanged: (v) => setState(() => _gender = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Age
                            Expanded(
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Age (Years)', '30'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Phone with +251 Default
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _phoneController,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                decoration: _inputDecoration('Phone Number (+251 Default) 🇪🇹', '+251 9...'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Phone required' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Section 2: Department Routing
                _buildSectionHeader('2. Department Routing & Attending Doctor Assignment'),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _department,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration('Department', ''),
                            items: const [
                              DropdownMenuItem(value: 'General OPD', child: Text('General OPD')),
                              DropdownMenuItem(value: 'Internal Medicine', child: Text('Internal Medicine')),
                              DropdownMenuItem(value: 'Pediatrics', child: Text('Pediatrics')),
                              DropdownMenuItem(value: 'Obstetrics & Gyn', child: Text('Obstetrics & Gyn')),
                            ],
                            onChanged: (v) => setState(() => _department = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _doctorName,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration('Assigned Doctor', ''),
                            items: const [
                              DropdownMenuItem(value: 'Dr. Sarah Chen, MD', child: Text('Dr. Sarah Chen, MD')),
                              DropdownMenuItem(value: 'Dr. Samuel Bekele, MD', child: Text('Dr. Samuel Bekele, MD')),
                            ],
                            onChanged: (v) => setState(() => _doctorName = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Section 4: Advance Patient Deposit (Flexible Credit Ledger)
                _buildSectionHeader('3. Advance Patient Deposit (Optional Flexible Credit Ledger)'),
                const SizedBox(height: 12),
                Card(
                  color: _collectAdvanceDeposit ? const Color(0xFF0F766E).withOpacity(0.15) : const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _collectAdvanceDeposit ? const Color(0xFF14B8A6) : const Color(0xFF334155)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Accept Advance Patient Deposit at Registration',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Credits patient centralized wallet for pharmacy & laboratory tests. Fully editable & refundable.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                          value: _collectAdvanceDeposit,
                          activeColor: const Color(0xFF14B8A6),
                          onChanged: (v) => setState(() => _collectAdvanceDeposit = v),
                        ),
                        if (_collectAdvanceDeposit) ...[
                          const Divider(color: Color(0xFF334155)),
                          Row(
                            children: [
                              ...[500.0, 1000.0, 1500.0, 2500.0].map((amt) {
                                final isSelected = _depositAmount == amt;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text('${amt.toInt()} ETB'),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF14B8A6),
                                    backgroundColor: const Color(0xFF0F172A),
                                    labelStyle: TextStyle(
                                      color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) => setState(() => _depositAmount = amt),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitOpdRegistration,
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text('Register Patient & Issue Queue Slip (350.00 ETB Consultation)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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

  // --- TAB 2: IPD Admission (Command 2: 4 fixed prices + blank box for cashier agreement) ---
  Widget _buildIpdAdmissionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _ipdFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('1. Inpatient Bed Allocation & Ward Assignment'),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _ipdPatientNameController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('Inpatient Name *', 'e.g. Taye Belay'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Patient name required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _wardName,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Target Ward', ''),
                                items: const [
                                  DropdownMenuItem(value: 'General Ward A', child: Text('General Ward A')),
                                  DropdownMenuItem(value: 'ICU / High Dependency', child: Text('ICU / High Dependency')),
                                  DropdownMenuItem(value: 'Maternity Ward', child: Text('Maternity Ward')),
                                  DropdownMenuItem(value: 'Pediatric Ward', child: Text('Pediatric Ward')),
                                ],
                                onChanged: (v) => setState(() => _wardName = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _bedNumber,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Available Bed', ''),
                                items: const [
                                  DropdownMenuItem(value: 'BED-01', child: Text('BED-01 (Occupied)')),
                                  DropdownMenuItem(value: 'BED-04', child: Text('BED-04 (Available)')),
                                  DropdownMenuItem(value: 'BED-07', child: Text('BED-07 (Available)')),
                                ],
                                onChanged: (v) => setState(() => _bedNumber = v!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // COMMAND 2: SECTION 3 IPD ADVANCE DEPOSIT WITH 4 FIXED BOXES + 1 BLANK BOX
                _buildSectionHeader('2. Section No 3: IPD Advance Deposit (Mandatory Initial Patient Deposit)'),
                const SizedBox(height: 4),
                const Text(
                  'Four fixed preset prices + blank box for cashier to fill according to patient and clinic agreement to be flexible.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Deposit Options (ETB):',
                              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isCustomAgreed ? 'Flexible Agreement Active' : 'Fixed Preset Selected',
                                style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Fixed Presets + The Blank Box
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // 4 Fixed Price Boxes
                            ..._fixedIpdPrices.map((amt) {
                              final isSelected = !_isCustomAgreed && _ipdDepositAmount == amt;
                              return ChoiceChip(
                                label: Text(ApiService.formatCurrency(amt)),
                                selected: isSelected,
                                selectedColor: const Color(0xFF4F46E5),
                                backgroundColor: const Color(0xFF0F172A),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _ipdDepositAmount = amt;
                                    _isCustomAgreed = false;
                                    _ipdCustomAgreedController.clear();
                                  });
                                },
                              );
                            }),

                            // The 5th Box: BLANK BOX for Cashier to Fill
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: _ipdCustomAgreedController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: 'Blank Box: Agreed ETB...',
                                  hintStyle: const TextStyle(color: Color(0xFF818CF8), fontSize: 11),
                                  filled: true,
                                  fillColor: _isCustomAgreed ? const Color(0xFF312E81) : const Color(0xFF0F172A),
                                  prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF818CF8), size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: _isCustomAgreed ? const Color(0xFF6366F1) : const Color(0xFF475569),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: _isCustomAgreed ? const Color(0xFF818CF8) : const Color(0xFF475569),
                                      width: _isCustomAgreed ? 2 : 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onChanged: (val) {
                                  final customVal = double.tryParse(val) ?? 0.0;
                                  setState(() {
                                    _ipdDepositAmount = customVal;
                                    _isCustomAgreed = val.isNotEmpty;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Deposit Amount Due at Reception:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  Text(
                                    _isCustomAgreed ? 'Agreement: Custom patient-clinic rate' : 'Standard mandatory IPD rate',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                  ),
                                ],
                              ),
                              Text(
                                ApiService.formatCurrency(_ipdDepositAmount),
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitIpdAdmission,
                    icon: const Icon(Icons.domain_add_rounded),
                    label: Text(
                      'Admit Patient & Record ${_isCustomAgreed ? "Agreed" : "Mandatory"} Deposit (${ApiService.formatCurrency(_ipdDepositAmount)})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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

  // --- TAB 3: Active OPD Queue ---
  Widget _buildQueueTab() {
    return _queueVisits.isEmpty
        ? const Center(child: Text('No active patients in queue', style: TextStyle(color: Color(0xFF94A3B8))))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _queueVisits.length,
            itemBuilder: (context, index) {
              final v = _queueVisits[index];
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D9488),
                    child: Text(
                      '#${v.queueNumber}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  title: Text(v.patientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'MRN: ${v.patientMrn} | Dept: ${v.department} | Doctor: ${v.doctorAssignedName}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: v.status == 'in_consultation' ? Colors.amber.withOpacity(0.2) : const Color(0xFF0D9488).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      v.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: v.status == 'in_consultation' ? Colors.amberAccent : const Color(0xFF2DD4BF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
