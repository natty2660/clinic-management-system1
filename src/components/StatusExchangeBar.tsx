import React from 'react';
import {
  Receipt,
  Stethoscope,
  HeartPulse,
  FlaskConical,
  Pill,
  Shield,
  Activity,
  ArrowRight,
  Lock,
  Clock,
  CheckCircle2,
  AlertTriangle,
  Zap,
  Radio,
  ScanLine,
  Microscope,
} from 'lucide-react';
import { DatabaseState, Role } from '../types/clinic';
import { formatCurrency, getBatchExpiryStatus } from '../utils/formatters';

interface StatusExchangeBarProps {
  db: DatabaseState;
  currentRole: Role;
  onSwitchWorkstation?: (role: Role) => void;
  onOpenRoadmap?: () => void;
  onOpenChaosLab?: () => void;
  isPhase1Active?: boolean;
  onTogglePhase1Guide?: () => void;
  isPhase2Active?: boolean;
  onTogglePhase2Guide?: () => void;
  isPhase3Active?: boolean;
  onTogglePhase3Guide?: () => void;
}

export const StatusExchangeBar: React.FC<StatusExchangeBarProps> = ({
  db,
  currentRole,
}) => {
  // Cashier metrics
  const unpaidChargesCount = db.charges.filter((c) => c.paymentStatus === 'pending').length;
  const todayTotalCollected = db.payments.reduce((acc, p) => acc + p.amount, 0);

  // Doctor metrics
  const waitingDoctorCount = db.visits.filter(
    (v) => (v.consultationPaid || v.emergencyOverridden) && v.status === 'waiting_doctor'
  ).length;
  const inConsultCount = db.visits.filter((v) => v.status === 'in_consultation').length;

  // Nurse metrics
  const waitingNurseCount = db.visits.filter(
    (v) => !v.vitals || Object.keys(v.vitals).length <= 2
  ).length;

  // Lab metrics
  const labBlockedUnpaid = db.labOrders.filter(
    (o) => o.paymentStatus === 'pending' && !o.overridden
  ).length;
  const labReadyForSample = db.labOrders.filter(
    (o) => (o.paymentStatus === 'paid' || o.overridden) && (o.status === 'paid' || o.status === 'ordered')
  ).length;
  const labInProgress = db.labOrders.filter(
    (o) => o.status === 'sample_taken' || o.status === 'in_progress'
  ).length;

  // Pharmacy metrics
  const rxBlockedUnpaid = db.prescriptions.filter(
    (p) => p.paymentStatus === 'pending' && !p.overridden
  ).length;
  const rxReadyToDispense = db.prescriptions.filter(
    (p) => (p.paymentStatus === 'paid' || p.overridden) && p.status !== 'dispensed' && p.status !== 'cancelled'
  ).length;
  
  // Stock alert count
  let expiringOrLowStockCount = 0;
  db.medicines.forEach((med) => {
    const totalQty = med.batches.reduce((sum, b) => sum + b.quantity, 0);
    if (totalQty <= med.reorderLevel) expiringOrLowStockCount++;
    med.batches.forEach((b) => {
      const exp = getBatchExpiryStatus(b.expiryDate, db.settings.expiryWarningDays);
      if (exp.status === 'expired' || exp.status === 'expiring_soon') {
        expiringOrLowStockCount++;
      }
    });
  });

  return (
    <div className="bg-slate-900/90 border-b border-slate-800 text-slate-300 px-4 py-2 text-xs">
      <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-2.5">
        {/* Status Exchange HUD Cards - Read-Only Live LAN Telemetry */}
        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto py-0.5 scrollbar-thin">
          <div className="flex items-center gap-1.5 text-[11px] font-bold text-teal-400 uppercase tracking-wider shrink-0 pr-1">
            <Activity className="w-3.5 h-3.5 text-teal-400 animate-pulse" />
            <span className="hidden sm:inline">LAN Status Exchange:</span>
          </div>

          {/* Cashier pill */}
          <div
            title="Cashier Desk: Real-time collections and pending balances across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'cashier'
                ? 'bg-emerald-950/70 border-emerald-500/80 text-emerald-200 ring-1 ring-emerald-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <Receipt className="w-3 h-3 text-emerald-400" />
            <span>Cashier:</span>
            <span className="font-bold text-white">{formatCurrency(todayTotalCollected, db.settings.currency)}</span>
            {unpaidChargesCount > 0 && (
              <span className="bg-amber-500/20 text-amber-300 px-1 rounded text-[10px]">
                {unpaidChargesCount} pending
              </span>
            )}
          </div>

          {/* Doctor pill */}
          <div
            title="Doctor OPD: Live patient queue waiting for consultation across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'doctor'
                ? 'bg-blue-950/70 border-blue-500/80 text-blue-200 ring-1 ring-blue-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <Stethoscope className="w-3 h-3 text-blue-400" />
            <span>Doctor OPD:</span>
            <span className="font-bold text-white">{waitingDoctorCount} in queue</span>
            {inConsultCount > 0 && (
              <span className="bg-blue-500/20 text-blue-300 px-1 rounded text-[10px]">
                {inConsultCount} in consult
              </span>
            )}
          </div>

          {/* Nurse pill */}
          <div
            title="Nurse Triage: Patients waiting for vital signs across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'nurse'
                ? 'bg-purple-950/70 border-purple-500/80 text-purple-200 ring-1 ring-purple-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <HeartPulse className="w-3 h-3 text-purple-400" />
            <span>Nurse:</span>
            <span className="font-bold text-white">{waitingNurseCount} triage</span>
          </div>

          {/* Lab pill */}
          <div
            title="Laboratory: Active lab orders and specimen collection status across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'laboratory'
                ? 'bg-amber-950/70 border-amber-500/80 text-amber-200 ring-1 ring-amber-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <FlaskConical className="w-3 h-3 text-amber-400" />
            <span>Lab:</span>
            <span className="font-bold text-white">{labReadyForSample + labInProgress} active</span>
            {labBlockedUnpaid > 0 && (
              <span className="bg-red-500/20 text-red-300 px-1 rounded text-[10px] flex items-center gap-0.5">
                <Lock className="w-2.5 h-2.5 inline" /> {labBlockedUnpaid} unpaid
              </span>
            )}
          </div>

          {/* Pharmacy pill */}
          <div
            title="Pharmacy: Verified prescriptions ready to dispense across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'pharmacy'
                ? 'bg-cyan-950/70 border-cyan-500/80 text-cyan-200 ring-1 ring-cyan-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <Pill className="w-3 h-3 text-cyan-400" />
            <span>Pharmacy:</span>
            <span className="font-bold text-white">{rxReadyToDispense} ready</span>
            {rxBlockedUnpaid > 0 && (
              <span className="bg-red-500/20 text-red-300 px-1 rounded text-[10px] flex items-center gap-0.5">
                <Lock className="w-2.5 h-2.5 inline" /> {rxBlockedUnpaid} unpaid
              </span>
            )}
          </div>

          {/* Ultrasound pill */}
          <div
            title="Ultrasound Suite: Imaging scan worklist queue across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'ultrasound'
                ? 'bg-indigo-950/70 border-indigo-500/80 text-indigo-200 ring-1 ring-indigo-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <Radio className="w-3 h-3 text-indigo-400" />
            <span>Ultrasound:</span>
            <span className="font-bold text-white">
              {(db.ultrasoundOrders || []).filter((o) => o.status !== 'completed').length} active
            </span>
          </div>

          {/* X-Ray pill */}
          <div
            title="Digital X-Ray: Radiography study queue across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'xray'
                ? 'bg-sky-950/70 border-sky-500/80 text-sky-200 ring-1 ring-sky-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <ScanLine className="w-3 h-3 text-sky-400" />
            <span>X-Ray:</span>
            <span className="font-bold text-white">
              {(db.xrayOrders || []).filter((o) => o.status !== 'completed').length} pending
            </span>
          </div>

          {/* Pathology pill */}
          <div
            title="Histopathology: Biopsy specimen queue across LAN"
            className={`flex items-center gap-2 px-2.5 py-1 rounded-lg border text-[11px] font-medium shrink-0 ${
              currentRole === 'pathology'
                ? 'bg-rose-950/70 border-rose-500/80 text-rose-200 ring-1 ring-rose-500/40'
                : 'bg-slate-800/80 border-slate-700/80 text-slate-300'
            }`}
          >
            <Microscope className="w-3 h-3 text-pink-400" />
            <span>Pathology:</span>
            <span className="font-bold text-white">
              {(db.pathologyOrders || []).filter((o) => o.status !== 'completed').length} queue
            </span>
          </div>
        </div>

        {/* System Info Tag */}
        <div className="shrink-0 hidden xl:flex items-center gap-2 text-[11px] text-slate-400 font-mono">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
          <span>LAN Queue Live Exchange (Read-Only)</span>
        </div>
      </div>
    </div>
  );
};
