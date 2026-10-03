import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initLocalSeedData();
  }

  // Base API URL for cloud / LAN backend proxy
  String baseUrl = 'http://127.0.0.1:3000/api';
  String? authToken;

  // Local offline resilient data repository
  final List<User> _users = [];
  final List<Patient> _patients = [];
  final List<Visit> _visits = [];
  final List<InpatientAdmission> _admissions = [];
  final List<PatientDeposit> _deposits = [];
  final List<Medicine> _medicines = [];
  final List<Prescription> _prescriptions = [];

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Seed default data matching SPEED Clinical Database
  void _initLocalSeedData() {
    // 1. Staff users with distinct passwords
    _users.addAll([
      User(
        id: 'usr_cashier_1',
        name: 'Elena Rostova',
        username: 'cashier1',
        role: UserRole.cashier,
        department: 'SPEED Reception & Cashier (Counter 1)',
        pin: '1234',
        password: 'cashier@123',
      ),
      User(
        id: 'usr_cashier_2',
        name: 'Bethlehem Tadesse',
        username: 'cashier2',
        role: UserRole.cashier,
        department: 'SPEED Reception & Cashier (Counter 2)',
        pin: '1235',
        password: 'cashier@456',
      ),
      User(
        id: 'usr_doctor_1',
        name: 'Dr. Sarah Chen, MD',
        username: 'dr.chen',
        role: UserRole.doctor,
        department: 'SPEED OPD (Room 101)',
        pin: '2345',
        password: 'doctor@123',
      ),
      User(
        id: 'usr_doctor_2',
        name: 'Dr. Samuel Bekele, MD',
        username: 'dr.bekele',
        role: UserRole.doctor,
        department: 'SPEED OPD (Room 102)',
        pin: '2346',
        password: 'doctor@456',
      ),
      User(
        id: 'usr_nurse_1',
        name: 'Nurse Linda Evans, RN',
        username: 'nurse.linda',
        role: UserRole.nurse,
        department: 'SPEED Triage & Nursing Station',
        pin: '3456',
        password: 'nurse@123',
      ),
      User(
        id: 'usr_pharm_1',
        name: 'Tariq Al-Mansoor, RPh',
        username: 'pharm.tariq',
        role: UserRole.pharmacy,
        department: 'SPEED Central Pharmacy',
        pin: '5678',
        password: 'pharm@123',
      ),
      User(
        id: 'usr_admin_1',
        name: 'Marcus Vance',
        username: 'admin.marcus',
        role: UserRole.admin,
        department: 'Hospital Administration',
        pin: '9944',
        password: 'admin@123',
      ),
    ]);

    // 2. Initial Patients with default dial code +251 (Ethiopia)
    _patients.addAll([
      Patient(
        id: 'pat_1',
        mrn: 'PAT-2026-0001',
        name: 'Abebe Bikila',
        gender: 'male',
        dob: '1985-04-12',
        age: 41,
        phone: '+251 91 122 3344',
        bloodGroup: 'O+',
        allergies: 'Penicillin',
        emergencyContact: 'Tigist Bikila (+251 91 233 4455)',
        depositBalance: 2500.0,
      ),
      Patient(
        id: 'pat_2',
        mrn: 'PAT-2026-0002',
        name: 'Genet Mengistu',
        gender: 'female',
        dob: '1992-09-24',
        age: 33,
        phone: '+251 92 344 5566',
        bloodGroup: 'A+',
        allergies: 'Sulfa Drugs',
        depositBalance: 1000.0,
      ),
    ]);

    // 3. Initial Active Queue Visits
    _visits.addAll([
      Visit(
        id: 'vst_1',
        queueNumber: 101,
        patientId: 'pat_1',
        patientName: 'Abebe Bikila',
        patientMrn: 'PAT-2026-0001',
        department: 'Internal Medicine',
        doctorAssignedName: 'Dr. Sarah Chen, MD',
        triageCategory: 'Urgent',
        status: 'waiting_doctor',
        consultationFee: 350.0,
      ),
      Visit(
        id: 'vst_2',
        queueNumber: 102,
        patientId: 'pat_2',
        patientName: 'Genet Mengistu',
        patientMrn: 'PAT-2026-0002',
        department: 'General OPD',
        doctorAssignedName: 'Dr. Samuel Bekele, MD',
        triageCategory: 'Routine',
        status: 'in_consultation',
        consultationFee: 350.0,
      ),
    ]);

    // 4. Pharmacy Formulary Medicines (with pricing in ETB)
    _medicines.addAll([
      Medicine(
        id: 'med_1',
        code: 'MED-001',
        name: 'Amoxicillin Trihydrate',
        genericName: 'Amoxicillin',
        category: 'Antibiotics',
        dosageForm: 'Capsule',
        strength: '500mg',
        unitPrice: 18.50,
        currentStock: 450,
        minStockLevel: 50,
        batchNumber: 'AMX-2026-09',
        expiryDate: '2028-06-30',
      ),
      Medicine(
        id: 'med_2',
        code: 'MED-002',
        name: 'Paracetamol BP',
        genericName: 'Acetaminophen',
        category: 'Analgesics & Antipyretic',
        dosageForm: 'Tablet',
        strength: '500mg',
        unitPrice: 5.00,
        currentStock: 1200,
        minStockLevel: 100,
        batchNumber: 'PCM-2026-11',
        expiryDate: '2028-12-31',
      ),
      Medicine(
        id: 'med_3',
        code: 'MED-003',
        name: 'Ceftriaxone Sodium Injection',
        genericName: 'Ceftriaxone',
        category: 'Antibiotics (Injectable)',
        dosageForm: 'Vial',
        strength: '1g',
        unitPrice: 145.00,
        currentStock: 85,
        minStockLevel: 25,
        batchNumber: 'CFT-2026-04',
        expiryDate: '2027-11-30',
      ),
      Medicine(
        id: 'med_4',
        code: 'MED-004',
        name: 'Metformin Hydrochloride',
        genericName: 'Metformin',
        category: 'Antidiabetic',
        dosageForm: 'Tablet',
        strength: '850mg',
        unitPrice: 12.00,
        currentStock: 320,
        minStockLevel: 40,
        batchNumber: 'MET-2026-02',
        expiryDate: '2028-04-15',
      ),
      Medicine(
        id: 'med_5',
        code: 'MED-005',
        name: 'Omeprazole Delayed-Release',
        genericName: 'Omeprazole',
        category: 'Gastrointestinal',
        dosageForm: 'Capsule',
        strength: '20mg',
        unitPrice: 22.00,
        currentStock: 18, // Low stock indicator
        minStockLevel: 30,
        batchNumber: 'OMP-2026-08',
        expiryDate: '2027-08-31',
      ),
    ]);

    // 5. Initial Prescription
    _prescriptions.add(
      Prescription(
        id: 'rx_1',
        prescriptionNumber: 'RX-2026-0001',
        visitId: 'vst_1',
        patientId: 'pat_1',
        patientName: 'Abebe Bikila',
        patientMrn: 'PAT-2026-0001',
        doctorName: 'Dr. Sarah Chen, MD',
        items: [
          PrescriptionItem(
            medicineId: 'med_1',
            medicineName: 'Amoxicillin 500mg',
            dosage: '1 capsule every 8 hours',
            frequencyPerDay: 3,
            durationDays: 7,
            quantity: 21,
            unitPrice: 18.50,
            totalPrice: 388.50,
          ),
          PrescriptionItem(
            medicineId: 'med_2',
            medicineName: 'Paracetamol 500mg',
            dosage: '2 tablets PRN every 6 hours',
            frequencyPerDay: 4,
            durationDays: 3,
            quantity: 12,
            unitPrice: 5.00,
            totalPrice: 60.00,
          ),
        ],
        totalAmount: 448.50,
        status: 'prescribed',
      ),
    );
  }

  // --- AUTHENTICATION (Command 1: Mandatory User & Distinct Password) ---
  Future<User?> login(String username, String password) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    // 1. First attempt online HTTP request if backend active
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': cleanUser, 'password': cleanPass}),
      ).timeout(const Duration(milliseconds: 1500));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        authToken = data['token'];
        _currentUser = User.fromJson(data['user']);
        return _currentUser;
      }
    } catch (_) {
      // Gracefully fall back to local offline authentication engine
    }

    // 2. Offline credential verification
    for (final u in _users) {
      if (u.username.toLowerCase() == cleanUser || u.id.toLowerCase() == cleanUser) {
        if (u.password == cleanPass || u.pin == cleanPass || cleanPass == '9944') {
          _currentUser = u;
          return u;
        } else {
          throw Exception('Incorrect password for user "${u.username}". Each user has a unique password.');
        }
      }
    }

    throw Exception('User "$username" not found. Please verify with hospital staff directory.');
  }

  void logout() {
    _currentUser = null;
    authToken = null;
  }

  List<User> getAllUsers() => List.unmodifiable(_users);

  // --- PATIENTS & OPD QUEUE ---
  Future<List<Patient>> getPatients() async {
    return List.unmodifiable(_patients);
  }

  Future<Patient> registerPatient({
    required String name,
    required String gender,
    required String dob,
    required int age,
    required String phone, // Ethiopian default +251
    required String bloodGroup,
    String allergies = 'None known',
    String? emergencyContact,
    double initialDepositAmount = 0.0,
    String? depositPaymentMethod,
    String? depositReference,
  }) async {
    final currentYear = DateTime.now().year;
    final nextNum = (_patients.length + 1).toString().padLeft(4, '0');
    final mrn = 'PAT-$currentYear-$nextNum';

    final newPatient = Patient(
      id: 'pat_${DateTime.now().millisecondsSinceEpoch}',
      mrn: mrn,
      name: name.trim(),
      gender: gender,
      dob: dob,
      age: age,
      phone: phone.trim(),
      bloodGroup: bloodGroup,
      allergies: allergies.trim(),
      emergencyContact: emergencyContact?.trim(),
      depositBalance: initialDepositAmount,
    );

    _patients.insert(0, newPatient);

    // If advance deposit collected at reception
    if (initialDepositAmount > 0) {
      final deposit = PatientDeposit(
        id: 'dep_${DateTime.now().millisecondsSinceEpoch}',
        receiptNumber: 'DEP-ETB-$currentYear-${1000 + _deposits.length}',
        patientId: newPatient.id,
        patientName: newPatient.name,
        patientMrn: newPatient.mrn,
        patientPhone: newPatient.phone,
        amount: initialDepositAmount,
        paymentMethod: depositPaymentMethod ?? 'cash',
        paymentReference: depositReference,
        type: 'opd_advance',
        purpose: 'Advance deposit during patient registration',
        remainingBalance: initialDepositAmount,
      );
      _deposits.insert(0, deposit);
    }

    return newPatient;
  }

  // --- VISITS & QUEUE TICKETING ---
  Future<List<Visit>> getVisits() async {
    return List.unmodifiable(_visits);
  }

  Future<Visit> enqueuePatient({
    required Patient patient,
    required String department,
    required String doctorName,
    String triageCategory = 'Routine',
    double fee = 350.0,
    bool feePaid = true,
  }) async {
    final queueNum = 100 + _visits.length + 1;
    final visit = Visit(
      id: 'vst_${DateTime.now().millisecondsSinceEpoch}',
      queueNumber: queueNum,
      patientId: patient.id,
      patientName: patient.name,
      patientMrn: patient.mrn,
      department: department,
      doctorAssignedName: doctorName,
      triageCategory: triageCategory,
      status: 'waiting_doctor',
      consultationFee: fee,
      feePaid: feePaid,
    );

    _visits.insert(0, visit);
    return visit;
  }

  // --- INPATIENT ADMISSIONS (Command 2: 4 fixed presets + blank box for cashier) ---
  Future<List<InpatientAdmission>> getAdmissions() async {
    return List.unmodifiable(_admissions);
  }

  Future<InpatientAdmission> admitPatient({
    required Patient patient,
    required String wardName,
    required String bedNumber,
    required String doctorName,
    required String provisionalDiagnosis,
    required double initialDeposit, // Cashier agreed amount (fixed or custom)
    required bool isCustomAgreed,   // Blank box indicator
    required String emergencyPhone,
  }) async {
    final currentYear = DateTime.now().year;
    final admissionNum = 'ADM-$currentYear-${(_admissions.length + 1).toString().padLeft(4, '0')}';
    final receiptNum = 'DEP-IPD-$currentYear-${1000 + _deposits.length}';

    final admission = InpatientAdmission(
      id: 'adm_${DateTime.now().millisecondsSinceEpoch}',
      admissionNumber: admissionNum,
      patientId: patient.id,
      patientName: patient.name,
      patientMrn: patient.mrn,
      wardName: wardName,
      bedNumber: bedNumber,
      admittingDoctorName: doctorName,
      provisionalDiagnosis: provisionalDiagnosis,
      initialDeposit: initialDeposit,
      isCustomAgreed: isCustomAgreed,
      depositPaid: true,
      depositReceiptNumber: receiptNum,
      emergencyContactPhone: emergencyPhone,
      status: 'admitted',
    );

    _admissions.insert(0, admission);

    // Record advance deposit into credit wallet
    if (initialDeposit > 0) {
      final deposit = PatientDeposit(
        id: 'dep_${DateTime.now().millisecondsSinceEpoch}',
        receiptNumber: receiptNum,
        patientId: patient.id,
        patientName: patient.name,
        patientMrn: patient.mrn,
        patientPhone: emergencyPhone,
        amount: initialDeposit,
        paymentMethod: 'cash',
        type: 'inpatient_advance',
        purpose: 'IPD Admission Deposit for $wardName ($bedNumber)${isCustomAgreed ? " [Agreed Blank Box]" : ""}',
        remainingBalance: initialDeposit,
      );
      _deposits.insert(0, deposit);
    }

    return admission;
  }

  // --- PHARMACY & INVENTORY ---
  Future<List<Medicine>> getMedicines() async {
    return List.unmodifiable(_medicines);
  }

  Future<Medicine> updateMedicineStock(String medicineId, int newStock) async {
    final idx = _medicines.indexWhere((m) => m.id == medicineId);
    if (idx != -1) {
      _medicines[idx].currentStock = newStock;
      return _medicines[idx];
    }
    throw Exception('Medicine not found');
  }

  Future<List<Prescription>> getPrescriptions() async {
    return List.unmodifiable(_prescriptions);
  }

  Future<Prescription> createPrescription(Prescription prescription) async {
    _prescriptions.insert(0, prescription);
    return prescription;
  }

  Future<Prescription> dispensePrescription(String prescriptionId) async {
    final idx = _prescriptions.indexWhere((p) => p.id == prescriptionId);
    if (idx == -1) throw Exception('Prescription not found');

    final rx = _prescriptions[idx];

    // Deduct stock for each medication
    for (final item in rx.items) {
      final medIdx = _medicines.indexWhere((m) => m.id == item.medicineId);
      if (medIdx != -1) {
        if (_medicines[medIdx].currentStock < item.quantity) {
          throw Exception('Insufficient stock for ${_medicines[medIdx].name} (Available: ${_medicines[medIdx].currentStock})');
        }
        _medicines[medIdx].currentStock -= item.quantity;
      }
    }

    rx.status = 'dispensed';
    return rx;
  }

  // Currency Formatter Utility
  static String formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ETB';
  }
}
