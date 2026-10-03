import 'dart:convert';

/// SPEED Clinical Roles
enum UserRole {
  cashier,
  doctor,
  nurse,
  laboratory,
  pharmacy,
  admin,
  ultrasound,
  xray,
  pathology;

  String get label {
    switch (this) {
      case UserRole.cashier:
        return 'Reception / Cashier';
      case UserRole.doctor:
        return 'OPD Doctor';
      case UserRole.nurse:
        return 'Triage & Nursing';
      case UserRole.laboratory:
        return 'Laboratory';
      case UserRole.pharmacy:
        return 'Pharmacy';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.ultrasound:
        return 'Ultrasound Suite';
      case UserRole.xray:
        return 'Digital X-Ray';
      case UserRole.pathology:
        return 'Histopathology';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return UserRole.doctor;
      case 'nurse':
        return UserRole.nurse;
      case 'laboratory':
        return UserRole.laboratory;
      case 'pharmacy':
        return UserRole.pharmacy;
      case 'admin':
        return UserRole.admin;
      case 'ultrasound':
        return UserRole.ultrasound;
      case 'xray':
        return UserRole.xray;
      case 'pathology':
        return UserRole.pathology;
      case 'cashier':
      default:
        return UserRole.cashier;
    }
  }
}

/// Clinical Staff User
class User {
  final String id;
  final String name;
  final String username;
  final UserRole role;
  final String department;
  final String pin;
  final String password;
  final bool active;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.department,
    required this.pin,
    required this.password,
    this.active = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      role: UserRole.fromString(json['role'] ?? 'cashier'),
      department: json['department'] ?? '',
      pin: json['pin'] ?? '1234',
      password: json['password'] ?? 'staff@123',
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'role': role.name,
        'department': department,
        'pin': pin,
        'password': password,
        'active': active,
      };
}

/// Patient Record
class Patient {
  final String id;
  final String mrn; // e.g. PAT-2026-0042
  final String name;
  final String gender;
  final String dob;
  final int age;
  final String phone; // Default code +251
  final String bloodGroup;
  final String allergies;
  final String? emergencyContact;
  final double depositBalance; // Advance credit balance (ETB)
  final DateTime registeredAt;

  Patient({
    required this.id,
    required this.mrn,
    required this.name,
    required this.gender,
    required this.dob,
    required this.age,
    required this.phone,
    required this.bloodGroup,
    this.allergies = 'None known',
    this.emergencyContact,
    this.depositBalance = 0.0,
    DateTime? registeredAt,
  }) : registeredAt = registeredAt ?? DateTime.now();

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      mrn: json['mrn'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? 'female',
      dob: json['dob'] ?? '',
      age: json['age'] ?? 0,
      phone: json['phone'] ?? '+251 91 000 0000',
      bloodGroup: json['bloodGroup'] ?? 'O+',
      allergies: json['allergies'] ?? 'None known',
      emergencyContact: json['emergencyContact'],
      depositBalance: (json['depositBalance'] as num?)?.toDouble() ?? 0.0,
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mrn': mrn,
        'name': name,
        'gender': gender,
        'dob': dob,
        'age': age,
        'phone': phone,
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'emergencyContact': emergencyContact,
        'depositBalance': depositBalance,
        'registeredAt': registeredAt.toIso8601String(),
      };
}

/// Inpatient Admission Record
class InpatientAdmission {
  final String id;
  final String admissionNumber; // e.g. ADM-2026-0012
  final String patientId;
  final String patientName;
  final String patientMrn;
  final String wardName;
  final String bedNumber;
  final String admittingDoctorName;
  final String provisionalDiagnosis;
  final double initialDeposit;
  final bool isCustomAgreed; // True when cashier filled custom blank box
  final bool depositPaid;
  final String depositReceiptNumber;
  final String emergencyContactPhone;
  final String status; // admitted, discharged, transferred
  final DateTime admittedAt;

  InpatientAdmission({
    required this.id,
    required this.admissionNumber,
    required this.patientId,
    required this.patientName,
    required this.patientMrn,
    required this.wardName,
    required this.bedNumber,
    required this.admittingDoctorName,
    required this.provisionalDiagnosis,
    required this.initialDeposit,
    this.isCustomAgreed = false,
    this.depositPaid = true,
    required this.depositReceiptNumber,
    required this.emergencyContactPhone,
    this.status = 'admitted',
    DateTime? admittedAt,
  }) : admittedAt = admittedAt ?? DateTime.now();

  factory InpatientAdmission.fromJson(Map<String, dynamic> json) {
    return InpatientAdmission(
      id: json['id'] ?? '',
      admissionNumber: json['admissionNumber'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      patientMrn: json['patientMrn'] ?? '',
      wardName: json['wardName'] ?? 'General Ward A',
      bedNumber: json['bedNumber'] ?? 'BED-01',
      admittingDoctorName: json['admittingDoctorName'] ?? 'Dr. Sarah Chen, MD',
      provisionalDiagnosis: json['provisionalDiagnosis'] ?? '',
      initialDeposit: (json['initialDeposit'] as num?)?.toDouble() ?? 3000.0,
      isCustomAgreed: json['isCustomAgreed'] ?? false,
      depositPaid: json['depositPaid'] ?? true,
      depositReceiptNumber: json['depositReceiptNumber'] ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] ?? '+251 9',
      status: json['status'] ?? 'admitted',
      admittedAt: json['admittedAt'] != null
          ? DateTime.tryParse(json['admittedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'admissionNumber': admissionNumber,
        'patientId': patientId,
        'patientName': patientName,
        'patientMrn': patientMrn,
        'wardName': wardName,
        'bedNumber': bedNumber,
        'admittingDoctorName': admittingDoctorName,
        'provisionalDiagnosis': provisionalDiagnosis,
        'initialDeposit': initialDeposit,
        'isCustomAgreed': isCustomAgreed,
        'depositPaid': depositPaid,
        'depositReceiptNumber': depositReceiptNumber,
        'emergencyContactPhone': emergencyContactPhone,
        'status': status,
        'admittedAt': admittedAt.toIso8601String(),
      };
}

/// Advance Patient Deposit Transaction
class PatientDeposit {
  final String id;
  final String receiptNumber; // e.g. DEP-ETB-2026-1234
  final String patientId;
  final String patientName;
  final String patientMrn;
  final String patientPhone;
  final double amount;
  final String paymentMethod; // cash, mobile_money, card, bank_transfer
  final String? paymentReference;
  final String type; // opd_advance, inpatient_advance, procedure_deposit, general_deposit
  final String purpose;
  final String status; // active, utilized, refunded, adjusted
  final double utilizedAmount;
  final double remainingBalance;
  final DateTime createdAt;

  PatientDeposit({
    required this.id,
    required this.receiptNumber,
    required this.patientId,
    required this.patientName,
    required this.patientMrn,
    required this.patientPhone,
    required this.amount,
    required this.paymentMethod,
    this.paymentReference,
    required this.type,
    required this.purpose,
    this.status = 'active',
    this.utilizedAmount = 0.0,
    required this.remainingBalance,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PatientDeposit.fromJson(Map<String, dynamic> json) {
    return PatientDeposit(
      id: json['id'] ?? '',
      receiptNumber: json['receiptNumber'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      patientMrn: json['patientMrn'] ?? '',
      patientPhone: json['patientPhone'] ?? '+251 9',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? 'cash',
      paymentReference: json['paymentReference'],
      type: json['type'] ?? 'opd_advance',
      purpose: json['purpose'] ?? 'Advance clinical deposit',
      status: json['status'] ?? 'active',
      utilizedAmount: (json['utilizedAmount'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (json['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'receiptNumber': receiptNumber,
        'patientId': patientId,
        'patientName': patientName,
        'patientMrn': patientMrn,
        'patientPhone': patientPhone,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'type': type,
        'purpose': purpose,
        'status': status,
        'utilizedAmount': utilizedAmount,
        'remainingBalance': remainingBalance,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Pharmacy Inventory Medicine Item
class Medicine {
  final String id;
  final String code; // e.g. MED-001
  final String name;
  final String genericName;
  final String category; // Antibiotics, Analgesics, Antidiabetic, etc.
  final String dosageForm; // Tablet, Syrup, Injection, Capsule
  final String strength; // e.g. 500mg, 1g, 100ml
  final double unitPrice; // in ETB
  int currentStock;
  final int minStockLevel;
  final String batchNumber;
  final String expiryDate; // YYYY-MM-DD

  Medicine({
    required this.id,
    required this.code,
    required this.name,
    required this.genericName,
    required this.category,
    required this.dosageForm,
    required this.strength,
    required this.unitPrice,
    required this.currentStock,
    this.minStockLevel = 20,
    required this.batchNumber,
    required this.expiryDate,
  });

  bool get isLowStock => currentStock <= minStockLevel;

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      genericName: json['genericName'] ?? '',
      category: json['category'] ?? 'General',
      dosageForm: json['dosageForm'] ?? 'Tablet',
      strength: json['strength'] ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      currentStock: json['currentStock'] ?? 0,
      minStockLevel: json['minStockLevel'] ?? 20,
      batchNumber: json['batchNumber'] ?? 'BATCH-001',
      expiryDate: json['expiryDate'] ?? '2027-12-31',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'genericName': genericName,
        'category': category,
        'dosageForm': dosageForm,
        'strength': strength,
        'unitPrice': unitPrice,
        'currentStock': currentStock,
        'minStockLevel': minStockLevel,
        'batchNumber': batchNumber,
        'expiryDate': expiryDate,
      };
}

/// Prescription Item
class PrescriptionItem {
  final String medicineId;
  final String medicineName;
  final String dosage; // e.g. 1 tab TID
  final int frequencyPerDay;
  final int durationDays;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  PrescriptionItem({
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.frequencyPerDay,
    required this.durationDays,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      medicineId: json['medicineId'] ?? '',
      medicineName: json['medicineName'] ?? '',
      dosage: json['dosage'] ?? '',
      frequencyPerDay: json['frequencyPerDay'] ?? 3,
      durationDays: json['durationDays'] ?? 5,
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'dosage': dosage,
        'frequencyPerDay': frequencyPerDay,
        'durationDays': durationDays,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };
}

/// Prescription Order
class Prescription {
  final String id;
  final String prescriptionNumber; // e.g. RX-2026-0042
  final String visitId;
  final String patientId;
  final String patientName;
  final String patientMrn;
  final String doctorName;
  final List<PrescriptionItem> items;
  final double totalAmount;
  String status; // prescribed, pending_payment, paid, dispensed, cancelled
  final DateTime createdAt;

  Prescription({
    required this.id,
    required this.prescriptionNumber,
    required this.visitId,
    required this.patientId,
    required this.patientName,
    required this.patientMrn,
    required this.doctorName,
    required this.items,
    required this.totalAmount,
    this.status = 'prescribed',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['id'] ?? '',
      prescriptionNumber: json['prescriptionNumber'] ?? '',
      visitId: json['visitId'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      patientMrn: json['patientMrn'] ?? '',
      doctorName: json['doctorName'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => PrescriptionItem.fromJson(item))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'prescribed',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'prescriptionNumber': prescriptionNumber,
        'visitId': visitId,
        'patientId': patientId,
        'patientName': patientName,
        'patientMrn': patientMrn,
        'doctorName': doctorName,
        'items': items.map((i) => i.toJson()).toList(),
        'totalAmount': totalAmount,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// OPD Visit & Queue Item
class Visit {
  final String id;
  final int queueNumber; // e.g. 101
  final String patientId;
  final String patientName;
  final String patientMrn;
  final String department;
  final String doctorAssignedName;
  final String triageCategory; // Routine, Urgent, Emergency
  String status; // waiting_doctor, in_consultation, completed
  final double consultationFee;
  final bool feePaid;
  final DateTime enqueuedAt;

  Visit({
    required this.id,
    required this.queueNumber,
    required this.patientId,
    required this.patientName,
    required this.patientMrn,
    required this.department,
    required this.doctorAssignedName,
    this.triageCategory = 'Routine',
    this.status = 'waiting_doctor',
    this.consultationFee = 350.0,
    this.feePaid = true,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] ?? '',
      queueNumber: json['queueNumber'] ?? 1,
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      patientMrn: json['patientMrn'] ?? '',
      department: json['department'] ?? 'General OPD',
      doctorAssignedName: json['doctorAssignedName'] ?? 'Dr. Sarah Chen, MD',
      triageCategory: json['triageCategory'] ?? 'Routine',
      status: json['status'] ?? 'waiting_doctor',
      consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 350.0,
      feePaid: json['feePaid'] ?? true,
      enqueuedAt: json['enqueuedAt'] != null
          ? DateTime.tryParse(json['enqueuedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'queueNumber': queueNumber,
        'patientId': patientId,
        'patientName': patientName,
        'patientMrn': patientMrn,
        'department': department,
        'doctorAssignedName': doctorAssignedName,
        'triageCategory': triageCategory,
        'status': status,
        'consultationFee': consultationFee,
        'feePaid': feePaid,
        'enqueuedAt': enqueuedAt.toIso8601String(),
      };
}
