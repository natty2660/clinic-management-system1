import React, { useState } from 'react';
import {
  Wallet,
  Search,
  PlusCircle,
  Edit3,
  DollarSign,
  Printer,
  CheckCircle2,
  Calendar,
  Phone,
  User,
  CreditCard,
  Building2,
  X,
  Clock,
  ArrowRight,
  Filter,
  Save,
  RotateCcw,
  Sparkles,
} from 'lucide-react';
import { DatabaseState, PatientDeposit, Patient, User as ClinicUser } from '../../types/clinic';
import { formatCurrency, formatDateTime } from '../../utils/formatters';
import { PrintContentType } from '../../components/PrintModal';

interface OpdAdvanceDepositsTabProps {
  db: DatabaseState;
  onUpdateDb: (updater: (prev: DatabaseState) => DatabaseState) => void;
  currentUser: ClinicUser;
  onPrint: (content: PrintContentType) => void;
  broadcast: (type: any, station: string, title: string, detail: string, payload?: any) => void;
}

export const OpdAdvanceDepositsTab: React.FC<OpdAdvanceDepositsTabProps> = ({
  db,
  onUpdateDb,
  currentUser,
  onPrint,
  broadcast,
}) => {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'utilized' | 'refunded'>('all');
  const [typeFilter, setTypeFilter] = useState<'all' | 'opd_advance' | 'inpatient_advance' | 'procedure_deposit' | 'general_deposit'>('all');

  // Modal State for New Deposit or Editing Existing Deposit
  const [isDepositModalOpen, setIsDepositModalOpen] = useState(false);
  const [editingDeposit, setEditingDeposit] = useState<PatientDeposit | null>(null);

  // Form Fields (using default Ethiopian phone prefix +251 9)
  const [selectedPatientId, setSelectedPatientId] = useState<string>('');
  const [patientName, setPatientName] = useState<string>('');
  const [patientMrn, setPatientMrn] = useState<string>('');
  const [patientPhone, setPatientPhone] = useState<string>('+251 9');
  const [depositAmount, setDepositAmount] = useState<number>(1000);
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'card' | 'mobile_money' | 'bank_transfer'>('cash');
  const [paymentReference, setPaymentReference] = useState<string>('');
  const [depositType, setDepositType] = useState<PatientDeposit['type']>('opd_advance');
  const [purpose, setPurpose] = useState<string>('Advance payment for consultation, laboratory workup and medications');
  const [notes, setNotes] = useState<string>('');
  const [depositStatus, setDepositStatus] = useState<PatientDeposit['status']>('active');
  const [remainingBalanceInput, setRemainingBalanceInput] = useState<number>(1000);

  const deposits = (db.patientDeposits || []).filter((dep) => {
    const matchesSearch =
      dep.patientName.toLowerCase().includes(search.toLowerCase()) ||
      dep.patientMrn.toLowerCase().includes(search.toLowerCase()) ||
      dep.receiptNumber.toLowerCase().includes(search.toLowerCase()) ||
      dep.patientPhone.includes(search) ||
      (dep.paymentReference && dep.paymentReference.toLowerCase().includes(search.toLowerCase()));

    const matchesStatus = statusFilter === 'all' || dep.status === statusFilter;
    const matchesType = typeFilter === 'all' || dep.type === typeFilter;

    return matchesSearch && matchesStatus && matchesType;
  });

  // Summary Metrics
  const totalDepositedAllTime = (db.patientDeposits || []).reduce((acc, d) => acc + d.amount, 0);
  const totalActiveAvailable = (db.patientDeposits || []).filter((d) => d.status === 'active').reduce((acc, d) => acc + d.remainingBalance, 0);
  const totalUtilized = (db.patientDeposits || []).reduce((acc, d) => acc + (d.utilizedAmount || 0), 0);

  // Open modal for NEW deposit
  const handleOpenNewDepositModal = (presetPatient?: Patient) => {
    setEditingDeposit(null);
    if (presetPatient) {
      setSelectedPatientId(presetPatient.id);
      setPatientName(presetPatient.name);
      setPatientMrn(presetPatient.mrn);
      setPatientPhone(presetPatient.phone || '+251 9');
    } else {
      setSelectedPatientId('');
      setPatientName('');
      setPatientMrn('');
      setPatientPhone('+251 9');
    }
    setDepositAmount(1500);
    setRemainingBalanceInput(1500);
    setPaymentMethod('cash');
    setPaymentReference('');
    setDepositType('opd_advance');
    setPurpose('Advance payment for consultation, laboratory workup and medications');
    setNotes('');
    setDepositStatus('active');
    setIsDepositModalOpen(true);
  };

  // Open modal for EDITING existing deposit
  const handleOpenEditDepositModal = (dep: PatientDeposit) => {
    setEditingDeposit(dep);
    setSelectedPatientId(dep.patientId);
    setPatientName(dep.patientName);
    setPatientMrn(dep.patientMrn);
    setPatientPhone(dep.patientPhone || '+251 9');
    setDepositAmount(dep.amount);
    setRemainingBalanceInput(dep.remainingBalance);
    setPaymentMethod(dep.paymentMethod);
    setPaymentReference(dep.paymentReference || '');
    setDepositType(dep.type);
    setPurpose(dep.purpose);
    setNotes(dep.notes || '');
    setDepositStatus(dep.status);
    setIsDepositModalOpen(true);
  };

  // Handle selecting existing patient from dropdown
  const handlePatientSelectChange = (patId: string) => {
    setSelectedPatientId(patId);
    const pat = db.patients.find((p) => p.id === patId);
    if (pat) {
      setPatientName(pat.name);
      setPatientMrn(pat.mrn);
      setPatientPhone(pat.phone || '+251 9');
    }
  };

  // Save (Create or Update) Deposit
  const handleSaveDeposit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!patientName.trim() || depositAmount <= 0) return;

    if (editingDeposit) {
      // EDIT MODE: Update existing deposit record with full audit tracking & flexible balance editing
      const finalRemaining = Math.max(0, Math.min(depositAmount, remainingBalanceInput));
      const difference = finalRemaining - (editingDeposit.remainingBalance || 0);

      const updatedDeposit: PatientDeposit = {
        ...editingDeposit,
        patientName: patientName.trim(),
        patientMrn: patientMrn.trim() || editingDeposit.patientMrn,
        patientPhone: patientPhone.trim(),
        amount: depositAmount,
        paymentMethod,
        paymentReference: paymentReference.trim() || undefined,
        type: depositType,
        purpose: purpose.trim(),
        notes: notes.trim() || undefined,
        status: depositStatus,
        remainingBalance: finalRemaining,
        utilizedAmount: Math.max(0, depositAmount - finalRemaining),
        lastModifiedAt: new Date().toISOString(),
        lastModifiedBy: currentUser.name,
        version: (editingDeposit.version || 1) + 1,
      };

      onUpdateDb((prev) => {
        const nextDeposits = (prev.patientDeposits || []).map((d) =>
          d.id === editingDeposit.id ? updatedDeposit : d
        );

        // Also update patient's aggregate deposit balance
        const nextPatients = prev.patients.map((p) => {
          if (p.id === updatedDeposit.patientId || p.mrn === updatedDeposit.patientMrn) {
            const currentBal = p.depositBalance || 0;
            return {
              ...p,
              phone: updatedDeposit.patientPhone,
              depositBalance: Math.max(0, currentBal + difference),
            };
          }
          return p;
        });

        return {
          ...prev,
          patientDeposits: nextDeposits,
          patients: nextPatients,
        };
      });

      broadcast(
        'DEPOSIT_UPDATED',
        'Reception PC',
        'Advance Deposit Modified',
        `Receipt ${updatedDeposit.receiptNumber} updated for ${updatedDeposit.patientName}: ${formatCurrency(depositAmount, db.settings.currency)} (${depositType.replace('_', ' ')}). Modified by ${currentUser.name}.`
      );

      setIsDepositModalOpen(false);
      setEditingDeposit(null);
    } else {
      // CREATE MODE: Create fresh advance deposit record
      const nextReceiptNumber = `DEP-ETB-2026-${Math.floor(1000 + Math.random() * 9000)}`;
      const targetMrn = patientMrn.trim() || `PAT-2026-${(db.patients.length + 1).toString().padStart(4, '0')}`;
      const targetPatId = selectedPatientId || `pat_${Date.now()}`;

      const newDeposit: PatientDeposit = {
        id: `dep_${Date.now()}`,
        receiptNumber: nextReceiptNumber,
        patientId: targetPatId,
        patientName: patientName.trim(),
        patientMrn: targetMrn,
        patientPhone: patientPhone.trim() || '+251 91 000 0000',
        amount: depositAmount,
        paymentMethod,
        paymentReference: paymentReference.trim() || undefined,
        type: depositType,
        purpose: purpose.trim(),
        status: 'active',
        utilizedAmount: 0,
        remainingBalance: depositAmount,
        notes: notes.trim() || undefined,
        createdAt: new Date().toISOString(),
        createdBy: currentUser.name,
        version: 1,
      };

      onUpdateDb((prev) => {
        // If patient already exists in DB, increment deposit balance
        let patientExists = false;
        const updatedPatients = prev.patients.map((p) => {
          if (p.id === targetPatId || p.mrn === targetMrn) {
            patientExists = true;
            return {
              ...p,
              phone: newDeposit.patientPhone,
              depositBalance: (p.depositBalance || 0) + depositAmount,
            };
          }
          return p;
        });

        // If not exist, auto-register patient record
        const finalPatients = patientExists
          ? updatedPatients
          : [
              {
                id: targetPatId,
                mrn: targetMrn,
                name: patientName.trim(),
                gender: 'other' as const,
                dob: '1995-01-01',
                age: 30,
                phone: newDeposit.patientPhone,
                bloodGroup: 'O+',
                allergies: [],
                registeredAt: new Date().toISOString(),
                depositBalance: depositAmount,
              },
              ...prev.patients,
            ];

        return {
          ...prev,
          patientDeposits: [newDeposit, ...(prev.patientDeposits || [])],
          patients: finalPatients,
        };
      });

      broadcast(
        'DEPOSIT_RECORDED',
        'Reception PC',
        'Advance Deposit Logged',
        `Receipt ${newDeposit.receiptNumber} credited for ${newDeposit.patientName} (${formatCurrency(depositAmount, db.settings.currency)} via ${paymentMethod.replace('_', ' ')}). Logged by ${currentUser.name}.`
      );

      // Print thermal/A4 advance deposit receipt
      onPrint({
        type: 'patient_deposit_receipt',
        data: newDeposit,
        settings: db.settings,
      });

      setIsDepositModalOpen(false);
      setEditingDeposit(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Banner & Quick Metrics */}
      <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="px-2 py-0.5 rounded text-[10px] font-black tracking-widest uppercase bg-emerald-600 text-white">
              ADVANCE DEPOSITS
            </span>
            <span className="text-xs font-semibold text-slate-500">Flexible & Fully Editable Credit Accounts</span>
          </div>
          <h2 className="text-lg font-black text-slate-900 mt-1 flex items-center gap-2">
            <Wallet className="w-5 h-5 text-emerald-600" />
            <span>Centralized Patient Advance Deposits & Credit Ledger</span>
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Accept advance deposits, update deposit records with full audit compliance, and credit patient accounts using standard Ethiopian dial codes (+251).
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <button
            type="button"
            onClick={() => handleOpenNewDepositModal()}
            className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold transition shadow-sm"
          >
            <PlusCircle className="w-4 h-4" />
            <span>+ Accept Advance Deposit</span>
          </button>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-2xs">
          <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider flex items-center justify-between">
            <span>Total Collected Advance</span>
            <DollarSign className="w-3.5 h-3.5 text-emerald-600" />
          </div>
          <div className="text-xl font-black text-slate-900 mt-1">
            {formatCurrency(totalDepositedAllTime, db.settings.currency)}
          </div>
          <div className="text-[11px] text-slate-500 mt-0.5 font-medium">Cumulative deposits registered</div>
        </div>

        <div className="bg-white rounded-xl border border-emerald-300 ring-1 ring-emerald-200/60 p-4 shadow-2xs">
          <div className="text-[10px] uppercase font-bold text-emerald-700 tracking-wider flex items-center justify-between">
            <span>Active Available Balance</span>
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
          </div>
          <div className="text-xl font-black text-emerald-700 mt-1">
            {formatCurrency(totalActiveAvailable, db.settings.currency)}
          </div>
          <div className="text-[11px] text-emerald-800 font-medium">Current unutilized patient credits</div>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-2xs">
          <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider flex items-center justify-between">
            <span>Total Utilized on Care</span>
            <Building2 className="w-3.5 h-3.5 text-indigo-600" />
          </div>
          <div className="text-xl font-black text-slate-900 mt-1">
            {formatCurrency(totalUtilized, db.settings.currency)}
          </div>
          <div className="text-[11px] text-slate-500 mt-0.5 font-medium">Applied to lab, medicines & procedures</div>
        </div>
      </div>

      {/* Filters & Search Toolbar */}
      <div className="bg-white rounded-xl border border-slate-200 p-3.5 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="relative flex-1 max-w-md">
          <Search className="w-3.5 h-3.5 absolute left-3 top-3 text-slate-400" />
          <input
            type="text"
            placeholder="Search deposit receipt#, patient name, MRN, phone (+251)..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
          />
          {search && (
            <button
              onClick={() => setSearch('')}
              className="absolute right-2.5 top-2 text-xs text-slate-400 hover:text-slate-600 font-bold"
            >
              ✕
            </button>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2 text-xs">
          <div className="flex items-center gap-1.5 bg-slate-50 px-2 py-1 rounded-lg border border-slate-200">
            <Filter className="w-3 h-3 text-slate-400" />
            <span className="text-slate-500 font-bold">Status:</span>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="bg-transparent font-medium focus:outline-none"
            >
              <option value="all">All Statuses</option>
              <option value="active">Active Credits</option>
              <option value="utilized">Utilized</option>
              <option value="refunded">Refunded / Closed</option>
            </select>
          </div>

          <div className="flex items-center gap-1.5 bg-slate-50 px-2 py-1 rounded-lg border border-slate-200">
            <span className="text-slate-500 font-bold">Category:</span>
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value as any)}
              className="bg-transparent font-medium focus:outline-none"
            >
              <option value="all">All Categories</option>
              <option value="opd_advance">OPD Advance</option>
              <option value="inpatient_advance">Inpatient Advance</option>
              <option value="procedure_deposit">Procedure Deposit</option>
              <option value="general_deposit">General Deposit</option>
            </select>
          </div>
        </div>
      </div>

      {/* Deposits Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider text-[10px]">
              <tr>
                <th className="py-3 px-4">Receipt #</th>
                <th className="py-3 px-4">Patient Demographics</th>
                <th className="py-3 px-4">Category & Purpose</th>
                <th className="py-3 px-4">Channel / Ref</th>
                <th className="py-3 px-4 text-right">Deposited</th>
                <th className="py-3 px-4 text-right">Available Balance</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {deposits.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-10 text-slate-400">
                    <Wallet className="w-8 h-8 mx-auto text-slate-300 mb-2 opacity-50" />
                    <p className="font-semibold">No advance deposits found matching current filters.</p>
                    <p className="text-[11px] mt-1">Click "+ Accept Advance Deposit" to register a patient credit balance.</p>
                  </td>
                </tr>
              ) : (
                deposits.map((dep) => (
                  <tr key={dep.id} className="hover:bg-slate-50/70 transition">
                    <td className="py-3 px-4 font-mono font-bold text-slate-900">
                      <div>{dep.receiptNumber}</div>
                      <div className="text-[10px] text-slate-400 font-normal font-sans">
                        {formatDateTime(dep.createdAt)}
                      </div>
                    </td>

                    <td className="py-3 px-4">
                      <div className="font-black text-slate-900">{dep.patientName}</div>
                      <div className="flex items-center gap-2 text-[10px] text-slate-500 font-mono mt-0.5">
                        <span className="font-bold text-teal-700">{dep.patientMrn}</span>
                        <span>•</span>
                        <span className="flex items-center gap-0.5">
                          <Phone className="w-2.5 h-2.5 text-slate-400" />
                          {dep.patientPhone}
                        </span>
                      </div>
                    </td>

                    <td className="py-3 px-4 max-w-xs">
                      <span className="inline-block px-1.5 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-slate-100 text-slate-800 border border-slate-200">
                        {dep.type.replace('_', ' ')}
                      </span>
                      <p className="text-[11px] text-slate-600 truncate mt-0.5 font-medium" title={dep.purpose}>
                        {dep.purpose}
                      </p>
                      {dep.notes && (
                        <p className="text-[10px] text-slate-400 italic truncate" title={dep.notes}>
                          Note: "{dep.notes}"
                        </p>
                      )}
                    </td>

                    <td className="py-3 px-4">
                      <span className="font-semibold uppercase text-slate-800">
                        {dep.paymentMethod.replace('_', ' ')}
                      </span>
                      {dep.paymentReference ? (
                        <div className="font-mono text-[10px] text-slate-500 mt-0.5">
                          Ref: {dep.paymentReference}
                        </div>
                      ) : (
                        <div className="text-[10px] text-slate-400">Cashier Counter</div>
                      )}
                    </td>

                    <td className="py-3 px-4 text-right font-mono font-bold text-slate-900">
                      {formatCurrency(dep.amount, db.settings.currency)}
                    </td>

                    <td className="py-3 px-4 text-right font-mono font-black">
                      <span className={dep.remainingBalance > 0 ? 'text-emerald-700' : 'text-slate-400'}>
                        {formatCurrency(dep.remainingBalance, db.settings.currency)}
                      </span>
                      {dep.utilizedAmount ? (
                        <div className="text-[10px] text-slate-400 font-normal">
                          Utilized: {formatCurrency(dep.utilizedAmount, db.settings.currency)}
                        </div>
                      ) : null}
                    </td>

                    <td className="py-3 px-4 text-center">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider ${
                          dep.status === 'active'
                            ? 'bg-emerald-100 text-emerald-800 border border-emerald-300'
                            : dep.status === 'utilized'
                            ? 'bg-blue-100 text-blue-800 border border-blue-300'
                            : dep.status === 'refunded'
                            ? 'bg-amber-100 text-amber-800 border border-amber-300'
                            : 'bg-slate-100 text-slate-700'
                        }`}
                      >
                        {dep.status}
                      </span>
                    </td>

                    <td className="py-3 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {/* Edit Button */}
                        <button
                          type="button"
                          onClick={() => handleOpenEditDepositModal(dep)}
                          className="p-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg transition"
                          title="Edit Deposit Details & Amount"
                        >
                          <Edit3 className="w-3.5 h-3.5" />
                        </button>

                        {/* Print Receipt Button */}
                        <button
                          type="button"
                          onClick={() =>
                            onPrint({
                              type: 'patient_deposit_receipt',
                              data: dep,
                              settings: db.settings,
                            })
                          }
                          className="p-1.5 bg-slate-100 hover:bg-emerald-50 text-emerald-700 rounded-lg transition"
                          title="Print Advance Deposit Receipt (ESC/POS)"
                        >
                          <Printer className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Deposit Creation / Editing Modal */}
      {isDepositModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-6 border border-slate-200 animate-in fade-in zoom-in-95 duration-150 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <div className="p-2 bg-emerald-100 text-emerald-800 rounded-xl">
                  {editingDeposit ? <Edit3 className="w-5 h-5" /> : <Wallet className="w-5 h-5" />}
                </div>
                <div>
                  <h3 className="text-base font-black text-slate-900">
                    {editingDeposit ? `Edit Advance Deposit (${editingDeposit.receiptNumber})` : 'Accept Patient Advance Deposit'}
                  </h3>
                  <p className="text-xs text-slate-500">
                    {editingDeposit ? 'Modify amount, payment reference, or clinical purpose' : 'Create flexible patient credit account with default dial code +251'}
                  </p>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setIsDepositModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveDeposit} className="my-4 space-y-4 text-xs">
              {/* Select Existing Patient or Type Custom */}
              {!editingDeposit && (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Select Registered Patient (Optional Quick-Fill)
                  </label>
                  <select
                    value={selectedPatientId}
                    onChange={(e) => handlePatientSelectChange(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white"
                  >
                    <option value="">-- Choose Existing Patient or Enter Below --</option>
                    {db.patients.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.mrn}) • {p.phone}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Patient Legal Name <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Samuel Kiprop"
                    value={patientName}
                    onChange={(e) => setPatientName(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 font-semibold"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Medical Record Number (MRN)</label>
                  <input
                    type="text"
                    placeholder="e.g. PAT-2026-0041"
                    value={patientMrn}
                    onChange={(e) => setPatientMrn(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono"
                  />
                </div>
              </div>

              {/* Ethiopian Phone Number Input with Default Code +251 */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  Patient Phone Number (Default Code +251) <span className="text-red-500">*</span>
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-400 font-bold font-mono">
                    🇪🇹
                  </div>
                  <input
                    type="text"
                    required
                    placeholder="+251 91 123 4567"
                    value={patientPhone}
                    onChange={(e) => setPatientPhone(e.target.value)}
                    className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono font-bold text-slate-900"
                  />
                </div>
                <p className="text-[11px] text-slate-400 mt-1">
                  Default format: <strong>+251 9...</strong> (Ethio Telecom / Safaricom Ethiopia)
                </p>
              </div>

              {/* Deposit Amount & Quick Presets */}
              <div className="bg-slate-50 p-3 rounded-xl border border-slate-200">
                <label className="block font-bold text-slate-800 mb-1">
                  Deposit Amount (ETB) <span className="text-red-500">*</span>
                </label>
                <input
                  type="number"
                  required
                  min="50"
                  step="50"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 text-base font-mono font-black border border-emerald-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white"
                />
                <div className="flex flex-wrap gap-1.5 mt-2">
                  {[500, 1000, 1500, 2500, 3500, 5000].map((amt) => (
                    <button
                      key={amt}
                      type="button"
                      onClick={() => setDepositAmount(amt)}
                      className={`px-2.5 py-1 rounded text-[11px] font-mono font-bold transition border ${
                        depositAmount === amt
                          ? 'bg-emerald-600 text-white border-emerald-600'
                          : 'bg-white hover:bg-slate-100 text-slate-700 border-slate-300'
                      }`}
                    >
                      {amt} Br
                    </button>
                  ))}
                </div>
              </div>

              {/* If editing, allow flexible adjustment of available remaining balance / refund */}
              {editingDeposit && (
                <div className="bg-amber-50/70 border border-amber-200 rounded-xl p-3 space-y-2">
                  <div className="flex items-center justify-between">
                    <label className="block font-bold text-amber-900 text-xs">
                      Editable Available Credit Balance (ETB)
                    </label>
                    <span className="text-[10px] text-amber-700 font-semibold font-mono">
                      Capped at Deposit: {formatCurrency(depositAmount, db.settings.currency)}
                    </span>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 items-center">
                    <input
                      type="number"
                      min="0"
                      max={depositAmount}
                      step="10"
                      value={remainingBalanceInput}
                      onChange={(e) => setRemainingBalanceInput(parseFloat(e.target.value) || 0)}
                      className="w-full px-3 py-1.5 font-mono font-black text-sm border border-amber-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-amber-500 bg-white text-amber-900"
                    />
                    <div className="flex gap-1.5">
                      <button
                        type="button"
                        onClick={() => {
                          setRemainingBalanceInput(0);
                          setDepositStatus('refunded');
                          setNotes((prev) => (prev ? `${prev} | Full refund processed at desk.` : 'Full refund processed at desk.'));
                        }}
                        className="flex-1 px-2.5 py-1.5 bg-amber-100 hover:bg-amber-200 text-amber-900 font-bold rounded-lg text-[10px] transition border border-amber-300"
                      >
                        Refund Bal (0 Br)
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setRemainingBalanceInput(depositAmount);
                          setDepositStatus('active');
                        }}
                        className="px-2.5 py-1.5 bg-white hover:bg-amber-50 text-amber-800 font-bold rounded-lg text-[10px] transition border border-amber-300"
                      >
                        Reset Full
                      </button>
                    </div>
                  </div>
                  <p className="text-[10px] text-amber-700">
                    Adjusting the balance directly updates the patient's centralized credit wallet and generates an audit log entry.
                  </p>
                </div>
              )}

              {/* Payment Channel */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">Payment Method / Channel</label>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  <button
                    type="button"
                    onClick={() => setPaymentMethod('cash')}
                    className={`p-2 rounded-lg border text-center transition font-bold text-xs ${
                      paymentMethod === 'cash'
                        ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                        : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                    }`}
                  >
                    💵 Cash
                  </button>
                  <button
                    type="button"
                    onClick={() => setPaymentMethod('mobile_money')}
                    className={`p-2 rounded-lg border text-center transition font-bold text-xs ${
                      paymentMethod === 'mobile_money'
                        ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                        : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                    }`}
                  >
                    📱 Telebirr
                  </button>
                  <button
                    type="button"
                    onClick={() => setPaymentMethod('card')}
                    className={`p-2 rounded-lg border text-center transition font-bold text-xs ${
                      paymentMethod === 'card'
                        ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                        : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                    }`}
                  >
                    💳 CBE / POS
                  </button>
                  <button
                    type="button"
                    onClick={() => setPaymentMethod('bank_transfer')}
                    className={`p-2 rounded-lg border text-center transition font-bold text-xs ${
                      paymentMethod === 'bank_transfer'
                        ? 'bg-emerald-600 text-white border-emerald-600 shadow-2xs'
                        : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
                    }`}
                  >
                    🏦 Transfer
                  </button>
                </div>
              </div>

              {/* Transaction Reference / Txn ID */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  Transaction Reference / Electronic Slip # (Optional)
                </label>
                <input
                  type="text"
                  placeholder="e.g. Telebirr Txn # TB-9018241 or POS RRN-00412"
                  value={paymentReference}
                  onChange={(e) => setPaymentReference(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono"
                />
              </div>

              {/* Deposit Type Category */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Deposit Category</label>
                  <select
                    value={depositType}
                    onChange={(e) => setDepositType(e.target.value as any)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white font-semibold"
                  >
                    <option value="opd_advance">OPD Advance (Outpatient)</option>
                    <option value="inpatient_advance">Inpatient Advance (Ward/Bed)</option>
                    <option value="procedure_deposit">Procedure / Surgery Deposit</option>
                    <option value="general_deposit">General Clinic Deposit</option>
                  </select>
                </div>

                {/* If editing, allow status change */}
                {editingDeposit && (
                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Account Status</label>
                    <select
                      value={depositStatus}
                      onChange={(e) => setDepositStatus(e.target.value as any)}
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white font-bold"
                    >
                      <option value="active">Active (Available for Clearance)</option>
                      <option value="utilized">Utilized (Cleared on Invoices)</option>
                      <option value="refunded">Refunded (Returned to Patient)</option>
                      <option value="adjusted">Adjusted / Audit Correction</option>
                    </select>
                  </div>
                )}
              </div>

              {/* Purpose */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">Deposit Purpose / Description</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Advance payment for consultation, laboratory workup and medications"
                  value={purpose}
                  onChange={(e) => setPurpose(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              {/* Internal Remarks */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">Internal Remarks / Cashier Notes</label>
                <textarea
                  rows={2}
                  placeholder="e.g. Paid in cash at front counter. Refundable upon clinical discharge."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div className="flex items-center justify-between pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsDepositModalOpen(false)}
                  className="px-4 py-2 text-slate-600 hover:bg-slate-100 rounded-xl font-bold transition"
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  className="inline-flex items-center gap-2 px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-black text-xs shadow-md transition"
                >
                  <Save className="w-4 h-4" />
                  <span>{editingDeposit ? 'Save Deposit Changes' : 'Confirm & Print Deposit Receipt'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
