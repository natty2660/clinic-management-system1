import React, { useState } from 'react';
import {
  UserPlus,
  Sparkles,
  Printer,
  Ticket,
  CheckCircle2,
  AlertCircle,
  Stethoscope,
  ShieldCheck,
  Zap,
  Phone,
  Clock,
  User,
  HeartPulse,
  Tag,
  DollarSign,
  Wallet,
} from 'lucide-react';
import { DatabaseState, Patient, Visit, EntryCard, ChargeItem, User as ClinicUser, PatientDeposit } from '../../types/clinic';
import { formatCurrency } from '../../utils/formatters';
import { PrintContentType } from '../../components/PrintModal';

interface OpdRegistrationTabProps {
  db: DatabaseState;
  onUpdateDb: (updater: (prev: DatabaseState) => DatabaseState) => void;
  currentUser: ClinicUser;
  onPrint: (content: PrintContentType) => void;
  broadcast: (type: any, station: string, title: string, detail: string, payload?: any) => void;
  onNavigateToQueue: () => void;
}

export const OpdRegistrationTab: React.FC<OpdRegistrationTabProps> = ({
  db,
  onUpdateDb,
  currentUser,
  onPrint,
  broadcast,
  onNavigateToQueue,
}) => {
  // Form fields
  const [name, setName] = useState('');
  const [gender, setGender] = useState<'male' | 'female' | 'other'>('female');
  const [dob, setDob] = useState('1998-05-20');
  const [age, setAge] = useState<number>(28);
  const [phone, setPhone] = useState('+251 9');
  const [nationalId, setNationalId] = useState('');
  const [emergencyContact, setEmergencyContact] = useState('');
  const [bloodGroup, setBloodGroup] = useState('O+');
  const [allergies, setAllergies] = useState('');
  const [department, setDepartment] = useState('General OPD');
  const [assignedDoctorId, setAssignedDoctorId] = useState<string>('usr_doctor_1');
  const [triageCategory, setTriageCategory] = useState<'Standard' | 'Urgent' | 'Emergency' | 'Elderly / Pediatric'>('Standard');
  const [feeOption, setFeeOption] = useState<'standard' | 'revisit' | 'emergency' | 'waived'>('standard');
  const [autoPayConsultation, setAutoPayConsultation] = useState(true);
  
  // Advanced Deposit Section (Optional on-the-spot credit balance)
  const [collectAdvanceDeposit, setCollectAdvanceDeposit] = useState<boolean>(false);
  const [depositAmount, setDepositAmount] = useState<number>(1000);
  const [depositMethod, setDepositMethod] = useState<'cash' | 'mobile_money' | 'card' | 'bank_transfer'>('cash');
  const [depositReference, setDepositReference] = useState<string>('');
  const [depositType, setDepositType] = useState<PatientDeposit['type']>('opd_advance');
  const [depositPurpose, setDepositPurpose] = useState<string>('Advance credit for consultation, laboratory workup & medicines');
  const [depositNotes, setDepositNotes] = useState<string>('');

  const [justEnqueuedVisit, setJustEnqueuedVisit] = useState<{ visit: Visit; card?: EntryCard; depositReceipt?: PatientDeposit } | null>(null);

  // Doctors list with waiting queues
  const doctors = db.users.filter((u) => u.role === 'doctor' && u.active);

  const getDoctorWaitingCount = (docId: string) => {
    return db.visits.filter(
      (v) => (v.status === 'waiting_doctor' || v.status === 'registered') && v.doctorAssignedId === docId
    ).length;
  };

  // Auto-calculate age from DOB
  const handleDobChange = (newDob: string) => {
    setDob(newDob);
    const bYear = new Date(newDob).getFullYear();
    const cYear = new Date().getFullYear();
    if (!isNaN(bYear) && bYear > 1900 && bYear <= cYear) {
      setAge(Math.max(1, cYear - bYear));
    }
  };

  // Quick Presets
  const applyPreset = (type: 'walk_in' | 'female_adult' | 'male_adult' | 'child_fever') => {
    const r = Math.floor(100 + Math.random() * 900);
    if (type === 'walk_in') {
      setName(`Walk-in Patient #${r}`);
      setGender('male');
      setAge(32);
      setDob('1994-03-12');
      setPhone(`+251 91 100 ${r}`);
      setDepartment('General OPD');
      setAllergies('NKDA');
    } else if (type === 'female_adult') {
      setName(`Hellen Wambui ${r}`);
      setGender('female');
      setAge(27);
      setDob('1999-08-14');
      setPhone(`+251 91 220 ${r}`);
      setDepartment('Gynecology & Obs');
      setAllergies('Penicillin (mild rash)');
      setAssignedDoctorId(doctors[1]?.id || doctors[0]?.id);
    } else if (type === 'male_adult') {
      setName(`Kassaye Zewdu ${r}`);
      setGender('male');
      setAge(45);
      setDob('1981-11-04');
      setPhone(`+251 91 330 ${r}`);
      setDepartment('Internal Medicine');
      setAllergies('None known');
    } else if (type === 'child_fever') {
      setName(`Baby Liam Otieno ${r}`);
      setGender('male');
      setAge(4);
      setDob('2022-06-18');
      setPhone(`+251 91 440 ${r}`);
      setDepartment('Pediatrics');
      setTriageCategory('Urgent');
      setAllergies('None known');
    }
  };

  const calculateFeeAmount = () => {
    if (feeOption === 'waived') return 0;
    if (feeOption === 'revisit') return db.settings.revisitConsultationFee || 200;
    if (feeOption === 'emergency') return (db.settings.consultationFee || 350) + 150;
    return db.settings.consultationFee || 350;
  };

  const handleRegisterAndEnqueue = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    const currentYear = new Date().getFullYear();
    const nextPatientNum = (db.patients.length + 1).toString().padStart(4, '0');
    const newMrn = `PAT-${currentYear}-${nextPatientNum}`;

    const newPatient: Patient = {
      id: `pat_${Date.now()}`,
      mrn: newMrn,
      name: name.trim(),
      gender,
      dob,
      age: age || 25,
      phone: phone.trim() || '+251 91 000 0000',
      nationalId: nationalId.trim() || undefined,
      emergencyContact: emergencyContact.trim() || undefined,
      bloodGroup,
      allergies: allergies.trim() ? allergies.split(',').map((a) => a.trim()) : [],
      registeredAt: new Date().toISOString(),
      depositBalance: collectAdvanceDeposit ? depositAmount : 0,
    };

    // Calculate queue number
    const todayQueueNum = db.visits.length + 101;
    const newVisitNum = `VST-${currentYear}-${(db.visits.length + 1).toString().padStart(4, '0')}`;
    const selectedDoc = doctors.find((d) => d.id === assignedDoctorId) || doctors[0];
    const feeAmount = calculateFeeAmount();

    const isPaid = autoPayConsultation || feeAmount === 0;

    const newVisit: Visit = {
      id: `vst_${Date.now()}`,
      visitNumber: newVisitNum,
      patientId: newPatient.id,
      patientName: newPatient.name,
      patientMrn: newPatient.mrn,
      patientAge: newPatient.age,
      patientGender: newPatient.gender,
      queueNumber: todayQueueNum,
      department,
      doctorAssignedId: selectedDoc?.id,
      doctorAssignedName: selectedDoc?.name,
      status: isPaid ? 'waiting_doctor' : 'registered',
      entryCardIssued: isPaid,
      consultationPaid: isPaid,
      emergencyOverridden: feeOption === 'waived',
      overrideReason: feeOption === 'waived' ? 'Consultation fee waived by front desk supervisor' : undefined,
      vitals: {
        recordedAt: new Date().toISOString(),
        triageCategory,
        painScore: 0,
      },
      createdAt: new Date().toISOString(),
      version: 1,
    };

    const newCharge: ChargeItem = {
      id: `chg_${Date.now()}`,
      visitId: newVisit.id,
      patientId: newPatient.id,
      category: 'consultation',
      name: `Doctor Consultation (${department}) - ${feeOption.toUpperCase()}`,
      unitPrice: feeAmount,
      quantity: 1,
      totalPrice: feeAmount,
      paymentStatus: isPaid ? 'paid' : 'pending',
      addedAt: new Date().toISOString(),
      addedBy: currentUser.name,
    };

    let issuedCard: EntryCard | undefined = undefined;
    if (isPaid) {
      issuedCard = {
        id: `card_${Date.now()}`,
        visitId: newVisit.id,
        patientMrn: newPatient.mrn,
        patientName: newPatient.name,
        queueNumber: newVisit.queueNumber,
        issuedAt: new Date().toISOString(),
        issuedBy: currentUser.name,
        paymentStatus: 'paid',
        qrCodeData: `SPEED:${newVisit.visitNumber}|MRN:${newPatient.mrn}|Q:${newVisit.queueNumber}|PAID`,
        barcode: newVisit.visitNumber.replace(/[^A-Za-z0-9]/g, ''),
      };
    }

    // Optional Advance Deposit creation on-the-fly
    let newDeposit: PatientDeposit | undefined = undefined;
    if (collectAdvanceDeposit && depositAmount > 0) {
      const depReceiptNum = `DEP-ETB-2026-${Math.floor(1000 + Math.random() * 9000)}`;
      newDeposit = {
        id: `dep_${Date.now()}`,
        receiptNumber: depReceiptNum,
        patientId: newPatient.id,
        patientName: newPatient.name,
        patientMrn: newPatient.mrn,
        patientPhone: newPatient.phone,
        amount: depositAmount,
        paymentMethod: depositMethod,
        paymentReference: depositReference.trim() || undefined,
        type: depositType,
        purpose: depositPurpose.trim() || 'Advance deposit for OPD laboratory workup and medications',
        status: 'active',
        utilizedAmount: 0,
        remainingBalance: depositAmount,
        linkedVisitId: newVisit.id,
        notes: depositNotes.trim() || 'Advance deposit registered during patient intake',
        createdAt: new Date().toISOString(),
        createdBy: currentUser.name,
        version: 1,
      };
    }

    onUpdateDb((prev) => ({
      ...prev,
      patients: [newPatient, ...prev.patients],
      visits: [newVisit, ...prev.visits],
      charges: [newCharge, ...prev.charges],
      entryCards: issuedCard ? [issuedCard, ...prev.entryCards] : prev.entryCards,
      patientDeposits: newDeposit ? [newDeposit, ...(prev.patientDeposits || [])] : prev.patientDeposits,
    }));

    broadcast(
      'PATIENT_REGISTERED',
      'Reception PC',
      'New OPD Registration',
      `${newPatient.name} [${newPatient.mrn}] registered for ${department} -> Queue #${newVisit.queueNumber}`
    );

    if (newDeposit) {
      broadcast(
        'DEPOSIT_RECORDED',
        'Reception PC',
        'Advance Deposit Logged',
        `Receipt ${newDeposit.receiptNumber} credited for ${newDeposit.patientName} (${formatCurrency(newDeposit.amount, db.settings.currency)}).`
      );
    }

    if (issuedCard) {
      broadcast(
        'ENTRY_CARD_ISSUED',
        'Reception PC',
        'Entry Slip Issued',
        `Queue #${newVisit.queueNumber} enqueued for ${selectedDoc?.name || 'OPD'}. Visible on Doctor PC.`
      );
    }

    setJustEnqueuedVisit({ visit: newVisit, card: issuedCard, depositReceipt: newDeposit });

    // Reset fields for next patient
    setName('');
    setPhone('+251 9');
    setNationalId('');
    setEmergencyContact('');
    setAllergies('');
    setCollectAdvanceDeposit(false);
    setDepositAmount(1000);
    setDepositMethod('cash');
    setDepositReference('');
    setDepositType('opd_advance');
    setDepositPurpose('Advance credit for consultation, laboratory workup & medicines');
    setDepositNotes('');
  };

  return (
    <div className="space-y-6">
      {/* Success Notification Banner if just enqueued */}
      {justEnqueuedVisit && (
        <div className="bg-emerald-50 border-2 border-emerald-500/80 rounded-xl p-4 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3 animate-in fade-in duration-200">
          <div className="flex items-start gap-3">
            <div className="p-2 bg-emerald-600 text-white rounded-lg">
              <CheckCircle2 className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-mono text-xs font-black bg-emerald-200 text-emerald-900 px-2 py-0.5 rounded">
                  QUEUE #{justEnqueuedVisit.visit.queueNumber}
                </span>
                <h4 className="font-black text-slate-900 text-sm">
                  {justEnqueuedVisit.visit.patientName} Successfully Enqueued!
                </h4>
              </div>
              <p className="text-xs text-slate-600 mt-0.5">
                MRN: <strong className="font-mono">{justEnqueuedVisit.visit.patientMrn}</strong> • Assigned to:{' '}
                <strong>{justEnqueuedVisit.visit.doctorAssignedName || 'OPD Doctor'}</strong> ({justEnqueuedVisit.visit.department})
                {justEnqueuedVisit.depositReceipt && (
                  <span className="ml-2 inline-flex items-center gap-1 font-bold text-emerald-800 bg-emerald-100/90 px-2 py-0.5 rounded text-[11px] border border-emerald-300">
                    <Wallet className="w-3 h-3 text-emerald-700" />
                    Deposit: {formatCurrency(justEnqueuedVisit.depositReceipt.amount, db.settings.currency)} ({justEnqueuedVisit.depositReceipt.receiptNumber})
                  </span>
                )}
              </p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {justEnqueuedVisit.card && (
              <button
                type="button"
                onClick={() =>
                  onPrint({
                    type: 'entry_card',
                    data: justEnqueuedVisit.card!,
                    settings: db.settings,
                  })
                }
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-700 hover:bg-emerald-800 text-white text-xs font-bold rounded-lg transition shadow-xs"
              >
                <Printer className="w-4 h-4" />
                <span>Print Entry Slip</span>
              </button>
            )}
            {justEnqueuedVisit.depositReceipt && (
              <button
                type="button"
                onClick={() =>
                  onPrint({
                    type: 'patient_deposit_receipt',
                    data: justEnqueuedVisit.depositReceipt!,
                    settings: db.settings,
                  })
                }
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-800 hover:bg-emerald-900 text-white text-xs font-bold rounded-lg transition shadow-xs"
              >
                <Printer className="w-4 h-4" />
                <span>Print Deposit Receipt ({formatCurrency(justEnqueuedVisit.depositReceipt.amount, db.settings.currency)})</span>
              </button>
            )}
            <button
              type="button"
              onClick={onNavigateToQueue}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold rounded-lg transition"
            >
              <Ticket className="w-4 h-4" />
              <span>View in Queue</span>
            </button>
            <button
              type="button"
              onClick={() => setJustEnqueuedVisit(null)}
              className="text-xs text-slate-400 hover:text-slate-600 px-2 py-1 font-bold"
            >
              ✕ Dismiss
            </button>
          </div>
        </div>
      )}

      {/* Preset Autofill Row */}
      <div className="bg-slate-50 border border-slate-200 rounded-xl p-3 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Zap className="w-4 h-4 text-amber-500" />
          <span className="text-xs font-bold text-slate-700">Rapid Demographic Presets:</span>
          <span className="text-[11px] text-slate-500">1-click test fill for front-desk speed testing</span>
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <button
            type="button"
            onClick={() => applyPreset('walk_in')}
            className="px-2.5 py-1 bg-white hover:bg-slate-100 border border-slate-300 rounded-md text-xs font-semibold text-slate-700 transition"
          >
            ⚡ Walk-In Express
          </button>
          <button
            type="button"
            onClick={() => applyPreset('female_adult')}
            className="px-2.5 py-1 bg-white hover:bg-slate-100 border border-slate-300 rounded-md text-xs font-semibold text-slate-700 transition"
          >
            👩 Adult Female (OB/GYN)
          </button>
          <button
            type="button"
            onClick={() => applyPreset('male_adult')}
            className="px-2.5 py-1 bg-white hover:bg-slate-100 border border-slate-300 rounded-md text-xs font-semibold text-slate-700 transition"
          >
            👨 Adult Male (Internal Med)
          </button>
          <button
            type="button"
            onClick={() => applyPreset('child_fever')}
            className="px-2.5 py-1 bg-white hover:bg-slate-100 border border-slate-300 rounded-md text-xs font-semibold text-slate-700 transition"
          >
            👶 Pediatric Infant
          </button>
        </div>
      </div>

      {/* Main Registration Form */}
      <form onSubmit={handleRegisterAndEnqueue} className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-6">
        <div>
          <h3 className="text-base font-black text-slate-900 flex items-center gap-2">
            <UserPlus className="w-5 h-5 text-teal-600" />
            <span>OPD Intake & Patient Details</span>
          </h3>
          <p className="text-xs text-slate-500 mt-0.5">
            Collect vital demographics, select attending physician, and generate thermal entry pass in a single rapid keystroke flow.
          </p>
        </div>

        {/* Section 1: Demographics */}
        <div className="space-y-4">
          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 border-b pb-1">
            1. Patient Demographics & Identification
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="md:col-span-2">
              <label className="block text-xs font-bold text-slate-700 mb-1">
                Full Legal Name <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                required
                placeholder="e.g. Samuel Kiprop"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none font-medium"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Gender</label>
              <select
                value={gender}
                onChange={(e) => setGender(e.target.value as any)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none bg-white font-medium"
              >
                <option value="female">Female</option>
                <option value="male">Male</option>
                <option value="other">Other</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Date of Birth</label>
              <input
                type="date"
                value={dob}
                onChange={(e) => handleDobChange(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Age (Years)</label>
              <input
                type="number"
                min="0"
                max="125"
                value={age}
                onChange={(e) => setAge(parseInt(e.target.value) || 0)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none font-mono"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1 flex items-center justify-between">
                <span>Phone (Default Code +251)</span>
                <span className="text-[10px] text-teal-600 font-bold">Ethiopia 🇪🇹</span>
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-2.5 flex items-center pointer-events-none text-xs text-slate-500 font-mono font-bold">
                  🇪🇹
                </div>
                <input
                  type="text"
                  placeholder="+251 91 123 4567"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="w-full pl-8 pr-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none font-mono font-bold text-slate-900"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Blood Group</label>
              <select
                value={bloodGroup}
                onChange={(e) => setBloodGroup(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none bg-white font-bold text-red-700"
              >
                <option value="O+">O Positive (O+)</option>
                <option value="O-">O Negative (O-)</option>
                <option value="A+">A Positive (A+)</option>
                <option value="A-">A Negative (A-)</option>
                <option value="B+">B Positive (B+)</option>
                <option value="B-">B Negative (B-)</option>
                <option value="AB+">AB Positive (AB+)</option>
                <option value="AB-">AB Negative (AB-)</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">National ID / Passport #</label>
              <input
                type="text"
                placeholder="ID-9923841"
                value={nationalId}
                onChange={(e) => setNationalId(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none font-mono"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Emergency Contact & Phone</label>
              <input
                type="text"
                placeholder="Next of kin name & contact"
                value={emergencyContact}
                onChange={(e) => setEmergencyContact(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Known Drug Allergies</label>
              <input
                type="text"
                placeholder="e.g. Penicillin, Sulfa, NSAIDs (or NKDA)"
                value={allergies}
                onChange={(e) => setAllergies(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none text-red-600 font-medium"
              />
            </div>
          </div>
        </div>

        {/* Section 2: Clinical Department & Doctor Routing */}
        <div className="space-y-4 pt-2">
          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 border-b pb-1">
            2. Department Routing & Attending Doctor Assignment
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Clinic Department</label>
              <select
                value={department}
                onChange={(e) => setDepartment(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none bg-white font-semibold"
              >
                <option value="General OPD">General OPD (Outpatient)</option>
                <option value="Internal Medicine">Internal Medicine Specialist</option>
                <option value="Pediatrics">Pediatrics & Child Health</option>
                <option value="Gynecology & Obs">Gynecology & Obstetrics</option>
                <option value="General Surgery">General Surgery Clinic</option>
                <option value="Orthopedics">Orthopedics & Trauma</option>
                <option value="Dental Clinic">Dental Surgery & Care</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Attending Physician (Room)</label>
              <select
                value={assignedDoctorId}
                onChange={(e) => setAssignedDoctorId(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:outline-none bg-white font-semibold"
              >
                {doctors.map((doc) => {
                  const waiting = getDoctorWaitingCount(doc.id);
                  return (
                    <option key={doc.id} value={doc.id}>
                      {doc.name} • {doc.department} ({waiting} waiting)
                    </option>
                  );
                })}
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Triage Priority Level</label>
              <select
                value={triageCategory}
                onChange={(e) => setTriageCategory(e.target.value as any)}
                className={`w-full px-3 py-2 text-xs border rounded-lg focus:outline-none font-bold ${
                  triageCategory === 'Emergency'
                    ? 'border-red-500 bg-red-50 text-red-900 ring-1 ring-red-400'
                    : triageCategory === 'Urgent'
                    ? 'border-amber-500 bg-amber-50 text-amber-900'
                    : 'border-slate-300 bg-white text-slate-800'
                }`}
              >
                <option value="Standard">Level 4: Standard / Non-Urgent</option>
                <option value="Urgent">Level 2: Urgent / High Priority</option>
                <option value="Emergency">Level 1: STAT Resuscitation / Immediate</option>
                <option value="Elderly / Pediatric">Priority: Elderly (&gt;65) or Infant (&lt;5)</option>
              </select>
            </div>
          </div>
        </div>

        {/* Section 3: Consultation Fee & Auto-Issuance */}
        <div className="space-y-4 pt-2">
          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 border-b pb-1">
            3. Consultation Fee & Entry Card Gate
          </div>

          <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="space-y-2">
              <div className="text-xs font-bold text-slate-800">Consultation Fee Billing Option</div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => setFeeOption('standard')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-lg border transition ${
                    feeOption === 'standard'
                      ? 'bg-teal-600 text-white border-teal-600 shadow-2xs'
                      : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-100'
                  }`}
                >
                  Standard ({formatCurrency(db.settings.consultationFee || 350, db.settings.currency)})
                </button>
                <button
                  type="button"
                  onClick={() => setFeeOption('revisit')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-lg border transition ${
                    feeOption === 'revisit'
                      ? 'bg-teal-600 text-white border-teal-600 shadow-2xs'
                      : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-100'
                  }`}
                >
                  Revisit Follow-up ({formatCurrency(db.settings.revisitConsultationFee || 200, db.settings.currency)})
                </button>
                <button
                  type="button"
                  onClick={() => setFeeOption('emergency')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-lg border transition ${
                    feeOption === 'emergency'
                      ? 'bg-red-600 text-white border-red-600 shadow-2xs'
                      : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-100'
                  }`}
                >
                  Emergency Fast-track (+150 ETB)
                </button>
                <button
                  type="button"
                  onClick={() => setFeeOption('waived')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-lg border transition ${
                    feeOption === 'waived'
                      ? 'bg-amber-600 text-white border-amber-600 shadow-2xs'
                      : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-100'
                  }`}
                >
                  Free / Waived (0 ETB)
                </button>
              </div>

              <label className="flex items-center gap-2 cursor-pointer pt-1">
                <input
                  type="checkbox"
                  checked={autoPayConsultation}
                  onChange={(e) => setAutoPayConsultation(e.target.checked)}
                  className="rounded text-teal-600 focus:ring-teal-500 w-4 h-4"
                />
                <span className="text-xs font-medium text-slate-700">
                  Patient tendered cash immediately at reception (Mark Consultation Fee as PAID & Issue Queue Entry Card)
                </span>
              </label>
            </div>

            <div className="text-right border-l md:border-l border-slate-200 md:pl-4">
              <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">Fee Due at Desk</span>
              <span className="text-2xl font-black text-slate-900">
                {formatCurrency(calculateFeeAmount(), db.settings.currency)}
              </span>
            </div>
          </div>
        </div>

        {/* Section 4: Advanced Deposit (Editable & Flexible Credit Section - Default Tel Code +251) */}
        <div className="space-y-4 pt-2">
          <div className="flex items-center justify-between border-b pb-1">
            <div className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <Wallet className="w-3.5 h-3.5 text-emerald-600" />
              <span>4. Advanced Deposit (Editable Flexible Credit Section)</span>
            </div>
            <span className="text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
              Default Tel Code: +251 🇪🇹
            </span>
          </div>

          <div
            className={`rounded-xl border transition-all ${
              collectAdvanceDeposit
                ? 'bg-emerald-50/50 border-emerald-300 p-4 shadow-xs'
                : 'bg-slate-50 border-slate-200 p-4'
            }`}
          >
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <label className="flex items-start sm:items-center gap-3 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={collectAdvanceDeposit}
                  onChange={(e) => setCollectAdvanceDeposit(e.target.checked)}
                  className="rounded text-emerald-600 focus:ring-emerald-500 w-5 h-5 mt-0.5 sm:mt-0"
                />
                <div>
                  <div className="text-xs font-bold text-slate-900 flex items-center gap-2">
                    <span>Accept Advance Patient Deposit at Registration</span>
                    <span className="px-1.5 py-0.2 rounded text-[10px] bg-emerald-600 text-white font-black tracking-wider uppercase">
                      Flexible Credit Ledger
                    </span>
                  </div>
                  <p className="text-[11px] text-slate-500 mt-0.5">
                    Credit patient account in advance for upcoming laboratory tests, prescribed medications, or procedures. Fully editable and refundable.
                  </p>
                </div>
              </label>

              {collectAdvanceDeposit && (
                <div className="shrink-0 text-right">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">Deposit Tendered</span>
                  <span className="text-xl font-black text-emerald-700">
                    {formatCurrency(depositAmount, db.settings.currency)}
                  </span>
                </div>
              )}
            </div>

            {/* Expanded Editable Deposit Controls */}
            {collectAdvanceDeposit && (
              <div className="mt-4 pt-4 border-t border-emerald-200/80 space-y-4 animate-in fade-in duration-200">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Deposit Amount & Quick Presets */}
                  <div className="md:col-span-1 space-y-2">
                    <label className="block text-xs font-bold text-slate-700">
                      Deposit Amount (ETB) <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="number"
                      min="50"
                      step="50"
                      value={depositAmount}
                      onChange={(e) => setDepositAmount(parseFloat(e.target.value) || 0)}
                      className="w-full px-3 py-2 text-sm font-mono font-black border border-emerald-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-none bg-white text-slate-900"
                    />
                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {[500, 1000, 1500, 2500, 3500, 5000].map((amt) => (
                        <button
                          key={amt}
                          type="button"
                          onClick={() => setDepositAmount(amt)}
                          className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold transition border ${
                            depositAmount === amt
                              ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                              : 'bg-white hover:bg-slate-100 text-slate-700 border-slate-300'
                          }`}
                        >
                          {amt} Br
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Payment Channel */}
                  <div className="md:col-span-1 space-y-2">
                    <label className="block text-xs font-bold text-slate-700">Payment Channel</label>
                    <div className="grid grid-cols-2 gap-1.5">
                      <button
                        type="button"
                        onClick={() => setDepositMethod('cash')}
                        className={`p-2 rounded-lg border text-center text-xs font-bold transition ${
                          depositMethod === 'cash'
                            ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                            : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        💵 Cash
                      </button>
                      <button
                        type="button"
                        onClick={() => setDepositMethod('mobile_money')}
                        className={`p-2 rounded-lg border text-center text-xs font-bold transition ${
                          depositMethod === 'mobile_money'
                            ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                            : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        📱 Telebirr
                      </button>
                      <button
                        type="button"
                        onClick={() => setDepositMethod('card')}
                        className={`p-2 rounded-lg border text-center text-xs font-bold transition ${
                          depositMethod === 'card'
                            ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                            : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        💳 CBE / POS
                      </button>
                      <button
                        type="button"
                        onClick={() => setDepositMethod('bank_transfer')}
                        className={`p-2 rounded-lg border text-center text-xs font-bold transition ${
                          depositMethod === 'bank_transfer'
                            ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                            : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        🏦 Bank Transfer
                      </button>
                    </div>
                  </div>

                  {/* Category & Reference */}
                  <div className="md:col-span-1 space-y-2">
                    <div>
                      <label className="block text-xs font-bold text-slate-700 mb-1">Deposit Category</label>
                      <select
                        value={depositType}
                        onChange={(e) => setDepositType(e.target.value as any)}
                        className="w-full px-3 py-1.5 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-none bg-white font-semibold"
                      >
                        <option value="opd_advance">OPD Advance (Outpatient)</option>
                        <option value="inpatient_advance">Inpatient Advance (Ward/Admission)</option>
                        <option value="procedure_deposit">Procedure / Surgery Deposit</option>
                        <option value="general_deposit">General Clinic Deposit</option>
                      </select>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-slate-700 mb-1">Transaction Ref / Txn ID</label>
                      <input
                        type="text"
                        placeholder="e.g. TB-883910 or CBE-RRN-994"
                        value={depositReference}
                        onChange={(e) => setDepositReference(e.target.value)}
                        className="w-full px-3 py-1.5 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-none font-mono"
                      />
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1">Deposit Purpose / Description</label>
                    <input
                      type="text"
                      placeholder="e.g. Advance deposit for consultation, laboratory workup and medications"
                      value={depositPurpose}
                      onChange={(e) => setDepositPurpose(e.target.value)}
                      className="w-full px-3 py-1.5 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-none font-medium"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1">Internal Remarks / Cashier Notes</label>
                    <input
                      type="text"
                      placeholder="e.g. Verified with patient. Refundable balance upon doctor signoff."
                      value={depositNotes}
                      onChange={(e) => setDepositNotes(e.target.value)}
                      className="w-full px-3 py-1.5 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>

                {/* Combined Desk Settlement Calculation */}
                <div className="bg-white p-3 rounded-lg border border-emerald-200 flex flex-wrap items-center justify-between gap-3 text-xs">
                  <div className="flex items-center gap-3">
                    <span className="font-semibold text-slate-600">
                      Consultation Fee: <strong>{formatCurrency(autoPayConsultation ? calculateFeeAmount() : 0, db.settings.currency)}</strong>
                    </span>
                    <span className="text-slate-300">+</span>
                    <span className="font-semibold text-emerald-700">
                      Advance Deposit: <strong>{formatCurrency(depositAmount, db.settings.currency)}</strong>
                    </span>
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 uppercase font-bold text-[10px]">Total Desk Cash/Transfer Due:</span>
                    <span className="text-base font-black text-slate-900 bg-emerald-50 px-2.5 py-0.5 rounded border border-emerald-200 font-mono">
                      {formatCurrency(
                        (autoPayConsultation ? calculateFeeAmount() : 0) + depositAmount,
                        db.settings.currency
                      )}
                    </span>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Submit Actions */}
        <div className="pt-3 border-t border-slate-100 flex flex-col sm:flex-row items-center justify-between gap-3">
          <div className="text-xs text-slate-500 flex items-center gap-1.5">
            <ShieldCheck className="w-4 h-4 text-teal-600" />
            <span>Strict Clinic Rule: Patient is automatically routed to Doctor PC queue once consultation is cleared.</span>
          </div>

          <button
            type="submit"
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-black text-xs sm:text-sm rounded-xl transition shadow-md hover:shadow-lg"
          >
            <Ticket className="w-4 h-4" />
            <span>Register Patient & Issue Queue Ticket</span>
          </button>
        </div>
      </form>
    </div>
  );
};
