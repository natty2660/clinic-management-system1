import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClinicSyncProApp());
}

// ============================================================================
// DATA MODELS
// ============================================================================

enum StationStage {
  reception,
  doctor,
  pharmacy,
  discharged;

  String get label {
    switch (this) {
      case StationStage.reception:
        return 'Reception Desk';
      case StationStage.doctor:
        return 'Doctor Consultation';
      case StationStage.pharmacy:
        return 'Pharmacy & Billing';
      case StationStage.discharged:
        return 'Discharged / Completed';
    }
  }

  Color get color {
    switch (this) {
      case StationStage.reception:
        return const Color(0xFF0284C7); // Sky Blue
      case StationStage.doctor:
        return const Color(0xFF0D9488); // Teal
      case StationStage.pharmacy:
        return const Color(0xFFD97706); // Amber
      case StationStage.discharged:
        return const Color(0xFF16A34A); // Emerald
    }
  }
}

class PatientRecord {
  final String id;
  final String fullName;
  final int age;
  final String gender;
  final String phone;
  final String chiefComplaint;
  final DateTime intakeTime;
  StationStage stage;
  String? doctorNotes;
  String? diagnosis;
  List<PrescribedMedication> prescriptions;
  double billingTotal;
  bool isPaid;

  PatientRecord({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.phone,
    required this.chiefComplaint,
    required this.intakeTime,
    this.stage = StationStage.doctor,
    this.doctorNotes,
    this.diagnosis,
    List<PrescribedMedication>? prescriptions,
    this.billingTotal = 350.0, // Base consultation rate in ETB
    this.isPaid = false,
  }) : prescriptions = prescriptions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'age': age,
        'gender': gender,
        'phone': phone,
        'chiefComplaint': chiefComplaint,
        'intakeTime': intakeTime.toIso8601String(),
        'stage': stage.name,
        'doctorNotes': doctorNotes,
        'diagnosis': diagnosis,
        'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
        'billingTotal': billingTotal,
        'isPaid': isPaid,
      };

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
        id: json['id'],
        fullName: json['fullName'],
        age: json['age'],
        gender: json['gender'],
        phone: json['phone'],
        chiefComplaint: json['chiefComplaint'],
        intakeTime: DateTime.parse(json['intakeTime']),
        stage: StationStage.values.firstWhere((e) => e.name == json['stage']),
        doctorNotes: json['doctorNotes'],
        diagnosis: json['diagnosis'],
        prescriptions: (json['prescriptions'] as List<dynamic>?)
                ?.map((e) => PrescribedMedication.fromJson(e))
                .toList() ??
            [],
        billingTotal: (json['billingTotal'] as num).toDouble(),
        isPaid: json['isPaid'] ?? false,
      );
}

class PrescribedMedication {
  final String itemName;
  final String dosage;
  final int quantity;
  final double unitPrice;

  PrescribedMedication({
    required this.itemName,
    required this.dosage,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'dosage': dosage,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory PrescribedMedication.fromJson(Map<String, dynamic> json) =>
      PrescribedMedication(
        itemName: json['itemName'],
        dosage: json['dosage'],
        quantity: json['quantity'],
        unitPrice: (json['unitPrice'] as num).toDouble(),
      );
}

class InventoryItem {
  final String id;
  final String name;
  final String genericName;
  final String category;
  int currentStock;
  final int minAlertThreshold;
  final double unitPrice;

  InventoryItem({
    required this.id,
    required this.name,
    required this.genericName,
    required this.category,
    required this.currentStock,
    required this.minAlertThreshold,
    required this.unitPrice,
  });

  bool get isReorderAlert => currentStock <= minAlertThreshold;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genericName': genericName,
        'category': category,
        'currentStock': currentStock,
        'minAlertThreshold': minAlertThreshold,
        'unitPrice': unitPrice,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        name: json['name'],
        genericName: json['genericName'],
        category: json['category'],
        currentStock: json['currentStock'],
        minAlertThreshold: json['minAlertThreshold'],
        unitPrice: (json['unitPrice'] as num).toDouble(),
      );
}

// ============================================================================
// CENTRAL DESKTOP STATE CONTROLLER
// ============================================================================

class ClinicController extends ChangeNotifier {
  final List<PatientRecord> _queue = [];
  final List<InventoryItem> _inventory = [];
  String _activeStation = 'Reception Desk';

  List<PatientRecord> get queue => List.unmodifiable(_queue);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  String get activeStation => _activeStation;

  ClinicController() {
    _bootstrapSeedData();
  }

  void setActiveStation(String station) {
    _activeStation = station;
    notifyListeners();
  }

  void _bootstrapSeedData() {
    // Initial Stock Ledger
    _inventory.addAll([
      InventoryItem(
        id: 'MED-01',
        name: 'Amoxicillin 500mg',
        genericName: 'Amoxicillin',
        category: 'Antibiotic',
        currentStock: 140,
        minAlertThreshold: 30,
        unitPrice: 18.50,
      ),
      InventoryItem(
        id: 'MED-02',
        name: 'Paracetamol 500mg',
        genericName: 'Acetaminophen',
        category: 'Analgesic',
        currentStock: 350,
        minAlertThreshold: 50,
        unitPrice: 5.00,
      ),
      InventoryItem(
        id: 'MED-03',
        name: 'Ceftriaxone 1g Inj',
        genericName: 'Ceftriaxone Sodium',
        category: 'Injectable',
        currentStock: 18, // Triggers reorder alert
        minAlertThreshold: 25,
        unitPrice: 145.00,
      ),
      InventoryItem(
        id: 'MED-04',
        name: 'Metformin 850mg',
        genericName: 'Metformin HCl',
        category: 'Antidiabetic',
        currentStock: 95,
        minAlertThreshold: 20,
        unitPrice: 12.00,
      ),
      InventoryItem(
        id: 'MED-05',
        name: 'Omeprazole 20mg',
        genericName: 'Omeprazole',
        category: 'Gastrointestinal',
        currentStock: 12, // Triggers reorder alert
        minAlertThreshold: 20,
        unitPrice: 22.00,
      ),
    ]);

    // Initial Live Queue
    _queue.addAll([
      PatientRecord(
        id: 'PAT-2026-0001',
        fullName: 'Abebe Tadesse',
        age: 42,
        gender: 'Male',
        phone: '+251 91 123 4567',
        chiefComplaint: 'Acute chest tightness & dry cough',
        intakeTime: DateTime.now().subtract(const Duration(minutes: 35)),
        stage: StationStage.doctor,
      ),
      PatientRecord(
        id: 'PAT-2026-0002',
        fullName: 'Sara Mengistu',
        age: 28,
        gender: 'Female',
        phone: '+251 92 987 6543',
        chiefComplaint: 'Migraine and elevated fever (38.9 C)',
        intakeTime: DateTime.now().subtract(const Duration(minutes: 18)),
        stage: StationStage.doctor,
      ),
    ]);
  }

  // --- Reception Workflows ---
  void registerPatient({
    required String name,
    required int age,
    required String gender,
    required String phone,
    required String complaint,
  }) {
    final nextIdNumber = (_queue.length + 1).toString().padLeft(4, '0');
    final record = PatientRecord(
      id: 'PAT-${DateTime.now().year}-$nextIdNumber',
      fullName: name.trim(),
      age: age,
      gender: gender,
      phone: phone.trim(),
      chiefComplaint: complaint.trim(),
      intakeTime: DateTime.now(),
      stage: StationStage.doctor,
    );
    _queue.insert(0, record);
    notifyListeners();
  }

  // --- Doctor Workflows ---
  void forwardToPharmacy({
    required String patientId,
    required String clinicalNotes,
    required String diagnosis,
    required List<PrescribedMedication> prescriptions,
  }) {
    final patient = _queue.firstWhere((p) => p.id == patientId);
    patient.doctorNotes = clinicalNotes;
    patient.diagnosis = diagnosis;
    patient.prescriptions = prescriptions;

    // Calculate billing
    double rxTotal = prescriptions.fold(0.0, (sum, item) => sum + item.subtotal);
    patient.billingTotal = 350.0 + rxTotal; // Consultation + Meds
    patient.stage = StationStage.pharmacy;
    notifyListeners();
  }

  // --- Pharmacy & Billing Workflows ---
  bool dispenseAndSettle(String patientId) {
    final patient = _queue.firstWhere((p) => p.id == patientId);

    // Verify stock availability
    for (final rx in patient.prescriptions) {
      final invItem = _inventory.firstWhere((item) => item.name == rx.itemName);
      if (invItem.currentStock < rx.quantity) {
        return false; // Insufficient stock
      }
    }

    // Deduct stock
    for (final rx in patient.prescriptions) {
      final invItem = _inventory.firstWhere((item) => item.name == rx.itemName);
      invItem.currentStock -= rx.quantity;
    }

    patient.isPaid = true;
    patient.stage = StationStage.discharged;
    notifyListeners();
    return true;
  }

  void adjustInventoryStock(String itemId, int newQuantity) {
    final item = _inventory.firstWhere((i) => i.id == itemId);
    item.currentStock = newQuantity;
    notifyListeners();
  }
}

// Inherited Provider Pattern for Clean Multi-Screen Tree Access
class ClinicProvider extends InheritedNotifier<ClinicController> {
  const ClinicProvider({
    Key? key,
    required ClinicController controller,
    required Widget child,
  }) : super(key: key, notifier: controller, child: child);

  static ClinicController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ClinicProvider>()!.notifier!;
  }
}

// ============================================================================
// APPLICATION ROOT & CORPORATE MEDICAL THEME
// ============================================================================

class ClinicSyncProApp extends StatefulWidget {
  const ClinicSyncProApp({Key? key}) : super(key: key);

  @override
  State<ClinicSyncProApp> createState() => _ClinicSyncProAppState();
}

class _ClinicSyncProAppState extends State<ClinicSyncProApp> {
  final ClinicController _controller = ClinicController();

  @override
  Widget build(BuildContext context) {
    return ClinicProvider(
      controller: _controller,
      child: MaterialApp(
        title: 'ClinicSync Pro — Desktop Workstation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0D9488), // Medical Teal
            onPrimary: Color(0xFFFFFFFF),
            secondary: Color(0xFF0284C7), // Hospital Blue
            surface: Color(0xFF0F172A), // Deep Navy Slate
            surfaceVariant: Color(0xFF1E293B), // Card Slate
            background: Color(0xFF090D16), // Outer Dark
            error: Color(0xFFEF4444),
          ),
          scaffoldBackgroundColor: const Color(0xFF090D16),
          cardTheme: CardTheme(
            color: const Color(0xFF1E293B),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF334155), width: 1),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
            ),
            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          fontFamily: 'Segoe UI',
        ),
        home: const MainWindowShell(),
      ),
    );
  }
}

// ============================================================================
// MAIN WINDOW SHELL (Navigation Drawer & Header)
// ============================================================================

class MainWindowShell extends StatelessWidget {
  const MainWindowShell({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = ClinicProvider.of(context);
    final active = controller.activeStation;

    return Scaffold(
      body: Row(
        children: [
          // Collapsible Left Corporate Navigation Rail
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Column(
              children: [
                // Header Branding
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0D9488)),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF14B8A6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ClinicSync Pro',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Medical Station OS',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Station Selection Links
                const SizedBox(height: 12),
                _DrawerTile(
                  icon: Icons.badge_outlined,
                  title: 'Reception Desk',
                  subtitle: 'Patient intake & ticketing',
                  isSelected: active == 'Reception Desk',
                  onTap: () => controller.setActiveStation('Reception Desk'),
                ),
                _DrawerTile(
                  icon: Icons.stethoscope,
                  title: 'Doctor Station',
                  subtitle: 'Consultation & Rx printing',
                  isSelected: active == 'Doctor Station',
                  onTap: () => controller.setActiveStation('Doctor Station'),
                ),
                _DrawerTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Pharmacy & Billing',
                  subtitle: 'Ledger & Dispensing',
                  isSelected: active == 'Pharmacy & Billing',
                  onTap: () => controller.setActiveStation('Pharmacy & Billing'),
                ),

                const Spacer(),

                // Live Mesh & Hardware Indicator
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Windows LAN Node: OK',
                          style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.print_outlined, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Station Workspace
          Expanded(
            child: Column(
              children: [
                // Top App Bar Status Monitor
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        active.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                      Row(
                        children: [
                          _HeaderStatBadge(
                            label: 'Queue Size',
                            value: '${controller.queue.where((p) => p.stage != StationStage.discharged).length}',
                          ),
                          const SizedBox(width: 16),
                          _HeaderStatBadge(
                            label: 'Low Stock Alerts',
                            value: '${controller.inventory.where((i) => i.isReorderAlert).length}',
                            isAlert: controller.inventory.any((i) => i.isReorderAlert),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            DateFormat('EEE, MMM d, yyyy • HH:mm').format(DateTime.now()),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Selected Station Body
                Expanded(
                  child: Builder(
                    builder: (context) {
                      switch (active) {
                        case 'Doctor Station':
                          return const DoctorConsultationScreen();
                        case 'Pharmacy & Billing':
                          return const PharmacyBillingScreen();
                        case 'Reception Desk':
                        default:
                          return const ReceptionDeskScreen();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: const Color(0xFF0D9488).withOpacity(0.18),
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFF94A3B8),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _HeaderStatBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlert;

  const _HeaderStatBadge({
    required this.label,
    required this.value,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.withOpacity(0.2) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isAlert ? Colors.redAccent : const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.redAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATION 1: RECEPTION DESK SCREEN
// ============================================================================

class ReceptionDeskScreen extends StatefulWidget {
  const ReceptionDeskScreen({Key? key}) : super(key: key);

  @override
  State<ReceptionDeskScreen> createState() => _ReceptionDeskScreenState();
}

class _ReceptionDeskScreenState extends State<ReceptionDeskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController(text: '+251 9');
  final _complaintController = TextEditingController();
  String _gender = 'Female';

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _complaintController.dispose();
    super.dispose();
  }

  void _submitIntake(ClinicController controller) {
    if (!_formKey.currentState!.validate()) return;

    controller.registerPatient(
      name: _nameController.text,
      age: int.parse(_ageController.text),
      gender: _gender,
      phone: _phoneController.text,
      complaint: _complaintController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D9488),
        content: Text('Enqueued ${_nameController.text} for Doctor Consultation.'),
      ),
    );

    _nameController.clear();
    _ageController.clear();
    _complaintController.clear();
    _phoneController.text = '+251 9';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ClinicProvider.of(context);
    final waitingQueue = controller.queue;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Registration Form Panel
          Expanded(
            flex: 5,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF14B8A6)),
                          SizedBox(width: 8),
                          Text(
                            'Patient Intake Registration',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Route new arrivals immediately to Doctor Consultation triage.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const Divider(height: 28, color: Color(0xFF334155)),

                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Patient Full Name *'),
                        validator: (v) => v!.trim().isEmpty ? 'Enter patient name' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(labelText: 'Age (Years) *'),
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Valid age required' : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(labelText: 'Gender'),
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) => setState(() => _gender = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Contact Phone Number *'),
                        validator: (v) => v!.trim().length < 7 ? 'Valid phone required' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _complaintController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Chief Complaint & Triage Notes *',
                          hintText: 'e.g. Severe migraine, high fever, abdominal pain',
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Complaint details required' : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _submitIntake(controller),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Enqueue Patient & Issue Queue Slip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Realtime Live Queue Panel
          Expanded(
            flex: 6,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Hospital Queue',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${waitingQueue.length} records logged today',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFF334155)),
                    Expanded(
                      child: ListView.separated(
                        itemCount: waitingQueue.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E293B)),
                        itemBuilder: (context, index) {
                          final patient = waitingQueue[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: patient.stage.color.withOpacity(0.2),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: patient.stage.color, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  patient.fullName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${patient.age}y, ${patient.gender})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complaint: ${patient.chiefComplaint}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                                ),
                                Text(
                                  'ID: ${patient.id} • Intake: ${DateFormat('HH:mm').format(patient.intakeTime)}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: patient.stage.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: patient.stage.color.withOpacity(0.5)),
                              ),
                              child: Text(
                                patient.stage.label,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: patient.stage.color),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATION 2: DOCTOR CONSULTATION SCREEN (with Native Windows PDF Printing)
// ============================================================================

class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({Key? key}) : super(key: key);

  @override
  State<DoctorConsultationScreen> createState() => _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen> {
  PatientRecord? _activePatient;
  final _clinicalNotesController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _dosageController = TextEditingController(text: '1 tab TID x 5 days');

  InventoryItem? _selectedMed;
  final List<PrescribedMedication> _scriptItems = [];

  @override
  void dispose() {
    _clinicalNotesController.dispose();
    _diagnosisController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _addScriptItem() {
    if (_selectedMed == null) return;
    setState(() {
      _scriptItems.add(
        PrescribedMedication(
          itemName: _selectedMed!.name,
          dosage: _dosageController.text.trim(),
          quantity: 15,
          unitPrice: _selectedMed!.unitPrice,
        ),
      );
    });
  }

  // Native Windows Desktop Printing via 'printing' & 'pdf'
  Future<void> _printPhysicalScript(PatientRecord patient) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLINICSYNC PRO MEDICAL CENTER',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('OPD Doctor Consultation Script', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),

                // Patient Information
                pw.Text('PATIENT: ${patient.fullName.toUpperCase()} (ID: ${patient.id})',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Age/Gender: ${patient.age} Yrs / ${patient.gender} | Contact: ${patient.phone}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Diagnosis: ${_diagnosisController.text}',
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 12),

                pw.Text('Rx - MEDICATION ORDERS:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),

                pw.ListView.builder(
                  itemCount: _scriptItems.length,
                  itemBuilder: (context, idx) {
                    final item = _scriptItems[idx];
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${idx + 1}. ${item.itemName} (${item.dosage})',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Qty: ${item.quantity}', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    );
                  },
                ),

                pw.Spacer(),
                pw.Divider(thickness: 0.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Authorized Doctor Signature: _______________________',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Official Rx Stamp', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Spools native print dialog in Windows
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Script_${patient.id}',
    );
  }

  void _routeToPharmacy(ClinicController controller) {
    if (_activePatient == null) return;
    if (_diagnosisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Please enter diagnosis before forwarding.')),
      );
      return;
    }

    controller.forwardToPharmacy(
      patientId: _activePatient!.id,
      clinicalNotes: _clinicalNotesController.text,
      diagnosis: _diagnosisController.text,
      prescriptions: _scriptItems,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D9488),
        content: Text('${_activePatient!.fullName} routed to Pharmacy & Billing station.'),
      ),
    );

    setState(() {
      _activePatient = null;
      _clinicalNotesController.clear();
      _diagnosisController.clear();
      _scriptItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ClinicProvider.of(context);
    final waitingDoctors = controller.queue.where((p) => p.stage == StationStage.doctor).toList();
    final inventory = controller.inventory;

    if (_selectedMed == null && inventory.isNotEmpty) {
      _selectedMed = inventory.first;
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Triage Patient Selector
          Expanded(
            flex: 3,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Awaiting Consultation (${waitingDoctors.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Divider(height: 20, color: Color(0xFF334155)),
                    Expanded(
                      child: waitingDoctors.isEmpty
                          ? const Center(
                              child: Text('No patients waiting in queue.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            )
                          : ListView.builder(
                              itemCount: waitingDoctors.length,
                              itemBuilder: (context, idx) {
                                final p = waitingDoctors[idx];
                                final isSelected = _activePatient?.id == p.id;
                                return Card(
                                  color: isSelected ? const Color(0xFF0D9488).withOpacity(0.2) : const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                    subtitle: Text('Complaint: ${p.chiefComplaint}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF64748B)),
                                    onTap: () {
                                      setState(() {
                                        _activePatient = p;
                                        _clinicalNotesController.text = 'Patient presents with ${p.chiefComplaint}. Vitals stable.';
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Right: Active Medical Examination
          Expanded(
            flex: 8,
            child: _activePatient == null
                ? Card(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.medical_information_outlined, size: 48, color: Color(0xFF475569)),
                          SizedBox(height: 12),
                          Text('Select a patient from the queue to start clinical consult.', style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Patient Header Strip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activePatient!.fullName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    'ID: ${_activePatient!.id} • ${_activePatient!.age} Yrs • ${_activePatient!.gender} • Phone: ${_activePatient!.phone}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _printPhysicalScript(_activePatient!),
                                    icon: const Icon(Icons.print, size: 16),
                                    label: const Text('Print Physical Rx'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF38BDF8),
                                      side: const BorderSide(color: Color(0xFF38BDF8)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _routeToPharmacy(controller),
                                    icon: const Icon(Icons.send_rounded, size: 16),
                                    label: const Text('Route to Pharmacy & Billing'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Color(0xFF334155)),

                          // Diagnosis Input
                          TextFormField(
                            controller: _diagnosisController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Diagnostic Assessment / Clinical Impression *',
                              hintText: 'e.g. Acute Bronchitis, Type II Diabetes, Hypertension',
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Doctor Notes Field
                          TextFormField(
                            controller: _clinicalNotesController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Physician Clinical Observations & Patient History Notes',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Medication Builder
                          const Text(
                            'Prescription & Medication Order Formulary',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<InventoryItem>(
                                  value: _selectedMed,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(labelText: 'Available Medication'),
                                  items: inventory.map((item) {
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Text('${item.name} (${item.currentStock} in stock) - ${item.unitPrice} ETB'),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedMed = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _dosageController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(labelText: 'Dosage Regimen'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _addScriptItem,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  side: const BorderSide(color: Color(0xFF0D9488)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                child: const Text('+ Add Rx', style: TextStyle(color: Color(0xFF14B8A6))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Prescription Table
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: _scriptItems.isEmpty
                                  ? const Center(
                                      child: Text('No medications attached to this consultation yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    )
                                  : ListView.separated(
                                      itemCount: _scriptItems.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E293B)),
                                      itemBuilder: (context, idx) {
                                        final item = _scriptItems[idx];
                                        return ListTile(
                                          dense: true,
                                          title: Text(item.itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          subtitle: Text('Instructions: ${item.dosage}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${item.quantity} units • ${item.subtotal.toStringAsFixed(2)} ETB',
                                                  style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 12)),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                                onPressed: () => setState(() => _scriptItems.removeAt(idx)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATION 3: PHARMACY & BILLING SCREEN (with QR Code Tracking & Stock Ledger)
// ============================================================================

class PharmacyBillingScreen extends StatefulWidget {
  const PharmacyBillingScreen({Key? key}) : super(key: key);

  @override
  State<PharmacyBillingScreen> createState() => _PharmacyBillingScreenState();
}

class _PharmacyBillingScreenState extends State<PharmacyBillingScreen> {
  PatientRecord? _selectedBill;
  final _qrVerificationController = TextEditingController();

  @override
  void dispose() {
    _qrVerificationController.dispose();
    super.dispose();
  }

  void _verifyScannedToken(ClinicController controller) {
    final token = _qrVerificationController.text.trim();
    if (token.isEmpty) return;

    try {
      final match = controller.queue.firstWhere((p) => p.id == token || token.contains(p.id));
      setState(() => _selectedBill = match);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFF0D9488), content: Text('Found verified billing record for ${match.fullName}')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Invalid tracking barcode or token.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ClinicProvider.of(context);
    final pendingOrders = controller.queue.where((p) => p.stage == StationStage.pharmacy).toList();
    final inventory = controller.inventory;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Pending Settlement Orders & QR Scanner
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Tracking String / Scanner Widget
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scan Patient Tracking Token',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qrVerificationController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Paste or scan token (e.g. PAT-2026-0001)',
                                  prefixIcon: Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF14B8A6)),
                                ),
                                onFieldSubmitted: (_) => _verifyScannedToken(controller),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _verifyScannedToken(controller),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              child: const Text('Verify', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Order Queue List
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Settlement Orders (${pendingOrders.length})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const Divider(height: 20, color: Color(0xFF334155)),
                          Expanded(
                            child: pendingOrders.isEmpty
                                ? const Center(
                                    child: Text('No orders waiting for dispensing.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  )
                                : ListView.builder(
                                    itemCount: pendingOrders.length,
                                    itemBuilder: (context, idx) {
                                      final p = pendingOrders[idx];
                                      final isSelected = _selectedBill?.id == p.id;
                                      return Card(
                                        color: isSelected ? const Color(0xFFD97706).withOpacity(0.2) : const Color(0xFF0F172A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                          subtitle: Text('${p.prescriptions.length} items prescribed • ${p.billingTotal.toStringAsFixed(2)} ETB',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF64748B)),
                                          onTap: () => setState(() => _selectedBill = p),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Center/Right: Order Settlement & Stock Dashboard
          Expanded(
            flex: 7,
            child: Column(
              children: [
                // Selected Order Settlement Panel
                if (_selectedBill != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // QR Code Container for the Receipt
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            child: QrImageView(
                              data: 'INVOICE:${_selectedBill!.id}|AMOUNT:${_selectedBill!.billingTotal}|DATE:${DateTime.now().toIso8601String()}',
                              version: QrVersions.auto,
                              size: 90.0,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dispensing Settlement for ${_selectedBill!.fullName}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Diagnosis: ${_selectedBill!.diagnosis ?? "N/A"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                Text(
                                  'Items: ${_selectedBill!.prescriptions.map((e) => "${e.itemName} (x${e.quantity})").join(", ")}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_selectedBill!.billingTotal.toStringAsFixed(2)} ETB',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF22C55E)),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final success = controller.dispenseAndSettle(_selectedBill!.id);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF16A34A),
                                        content: Text('Payment cleared & medicines dispensed for ${_selectedBill!.fullName}'),
                                      ),
                                    );
                                    setState(() => _selectedBill = null);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.redAccent,
                                        content: Text('Stock level insufficient to dispense this prescription.'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Discharge & Settle'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Stock Level Status Dashboard
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Formulary Stock & Reorder Alert Dashboard',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('Live Local Inventory', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFF334155)),
                          Expanded(
                            child: ListView.separated(
                              itemCount: inventory.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E293B)),
                              itemBuilder: (context, idx) {
                                final item = inventory[idx];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    item.isReorderAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    color: item.isReorderAlert ? Colors.redAccent : const Color(0xFF22C55E),
                                    size: 20,
                                  ),
                                  title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  subtitle: Text('${item.category} • Unit Price: ${item.unitPrice.toStringAsFixed(2)} ETB',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item.isReorderAlert ? Colors.red.withOpacity(0.2) : const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: item.isReorderAlert ? Colors.redAccent : const Color(0xFF334155)),
                                        ),
                                        child: Text(
                                          '${item.currentStock} units',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: item.isReorderAlert ? Colors.redAccent : const Color(0xFF22C55E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF14B8A6)),
                                        tooltip: 'Restock +50 Units',
                                        onPressed: () {
                                          controller.adjustInventoryStock(item.id, item.currentStock + 50);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}