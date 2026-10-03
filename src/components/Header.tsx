import React, { useState, useEffect } from 'react';
import {
  Laptop,
  Radio,
  Volume2,
  VolumeX,
  Clock,
  Shield,
  ShieldCheck,
  Building2,
  Stethoscope,
  Receipt,
  FlaskConical,
  Pill,
  HeartPulse,
  ChevronDown,
  UserCheck,
  Lock,
  LogOut,
  Coins,
  ScanLine,
  Microscope,
} from 'lucide-react';
import { Role, User, ClinicSettings, WorkstationConfig } from '../types/clinic';
import { clinicAudio } from '../utils/audio';

interface HeaderProps {
  currentRole: Role;
  onRoleChange: (newRole: Role) => void;
  currentUser: User;
  onUserChange: (user: User) => void;
  allUsers: User[];
  settings: ClinicSettings;
  isOnline?: boolean;
  networkMode?: 'online' | 'intermittent' | 'offline';
  onOpenSyncDrawer?: () => void;
  onOpenWsDrawer?: () => void;
  wsEventCount?: number;
  offlineQueueDepth?: number;
  currentWorkstation?: WorkstationConfig;
  onOpenWorkstationSettings?: () => void;
  onLockScreen?: () => void;
  onLogout?: () => void;
  onOpenMeshDiagnostics?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  currentRole,
  onRoleChange,
  currentUser,
  onUserChange,
  allUsers,
  settings,
  currentWorkstation,
  onOpenWorkstationSettings,
  onLockScreen,
  onLogout,
}) => {
  const [time, setTime] = useState<string>('');
  const [isSoundOn, setIsSoundOn] = useState<boolean>(true);
  const [showUserDropdown, setShowUserDropdown] = useState<boolean>(false);

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setTime(
        now.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
        })
      );
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  const toggleSound = () => {
    const next = !isSoundOn;
    setIsSoundOn(next);
    clinicAudio.setSoundEnabled(next);
  };

  const workstations: {
    role: Role;
    label: string;
    stationName: string;
    icon: React.ReactNode;
  }[] = [
    {
      role: 'cashier',
      label: 'Reception',
      stationName: 'SPEED Reception Desk',
      icon: <Receipt className="w-4 h-4" />,
    },
    {
      role: 'doctor',
      label: 'Doctor',
      stationName: 'SPEED OPD & Doctor',
      icon: <Stethoscope className="w-4 h-4" />,
    },
    {
      role: 'nurse',
      label: 'Nurse',
      stationName: 'SPEED Triage & Nurse',
      icon: <HeartPulse className="w-4 h-4" />,
    },
    {
      role: 'laboratory',
      label: 'Laboratory',
      stationName: 'SPEED Laboratory',
      icon: <FlaskConical className="w-4 h-4" />,
    },
    {
      role: 'pharmacy',
      label: 'Pharmacy',
      stationName: 'SPEED Pharmacy',
      icon: <Pill className="w-4 h-4" />,
    },
    {
      role: 'ultrasound',
      label: 'Ultrasound',
      stationName: 'SPEED Ultrasound Suite',
      icon: <Radio className="w-4 h-4" />,
    },
    {
      role: 'xray',
      label: 'X-Ray',
      stationName: 'SPEED Digital X-Ray',
      icon: <ScanLine className="w-4 h-4" />,
    },
    {
      role: 'pathology',
      label: 'Pathology',
      stationName: 'SPEED Histopathology',
      icon: <Microscope className="w-4 h-4" />,
    },
    {
      role: 'admin',
      label: 'Admin',
      stationName: 'SPEED Admin',
      icon: <Shield className="w-4 h-4" />,
    },
  ];

  return (
    <header className="bg-slate-900 border-b border-slate-800 text-white sticky top-0 z-40 shadow-md">
      {/* Top Meta Bar */}
      <div className="px-4 py-1.5 bg-slate-950 border-b border-slate-800/80 flex flex-wrap justify-between items-center text-[11px] text-slate-400 gap-2">
        <div className="flex items-center gap-2.5 flex-wrap">
          {/* Clinic Brand */}
          <div className="flex items-center gap-1.5 text-teal-400 font-bold tracking-wide">
            <span className="w-2 h-2 rounded-full bg-teal-400"></span>
            <span className="text-white font-extrabold">{settings.clinicName}</span>
          </div>

          <span className="text-slate-700 hidden sm:inline">|</span>

          {/* Currency Badge - Exclusively Ethiopian Birr (ETB) */}
          <div className="flex items-center gap-1 font-mono text-[11px] bg-slate-900 text-emerald-400 px-2 py-0.5 rounded border border-slate-800 font-bold">
            <Coins className="w-3 h-3 text-emerald-400" />
            <span>ETB (Ethiopian Birr / Br)</span>
          </div>

          <span className="text-slate-700 hidden sm:inline">|</span>

          {/* Active Terminal ID & Hardware Mapping */}
          <button
            onClick={onOpenWorkstationSettings}
            className="flex items-center gap-1 font-mono text-[11px] bg-slate-900 hover:bg-slate-800 text-slate-300 px-2 py-0.5 rounded border border-slate-800 transition"
            title="Configure Active Desktop Workstation ID & Printer Mapping"
          >
            <Laptop className="w-3 h-3 text-teal-400" />
            <span className="font-bold">{currentWorkstation?.id || settings.activeWorkstationId || 'SPEED-WS-01'}</span>
            <span className="text-slate-500 hidden md:inline">({currentWorkstation?.roomOrCounter || 'Counter 1'})</span>
          </button>
        </div>

        {/* Right side controls */}
        <div className="flex items-center gap-3">
          {/* Sound Toggle */}
          <button
            onClick={toggleSound}
            className="text-slate-400 hover:text-white transition p-1"
            title={isSoundOn ? 'Audio chime enabled' : 'Muted'}
          >
            {isSoundOn ? (
              <Volume2 className="w-3.5 h-3.5 text-teal-400" />
            ) : (
              <VolumeX className="w-3.5 h-3.5 text-slate-500" />
            )}
          </button>

          {/* Station Screen Lock */}
          <button
            onClick={onLockScreen}
            className="flex items-center gap-1 px-2.5 py-0.5 bg-slate-900 hover:bg-slate-800 text-slate-300 hover:text-white rounded border border-slate-800 text-[11px] transition"
            title="Lock terminal screen immediately (PIN required to unlock)"
          >
            <Lock className="w-3 h-3 text-amber-400" />
            <span>Lock</span>
          </button>

          {/* Sign Out to Login Screen */}
          {onLogout && (
            <button
              onClick={onLogout}
              className="flex items-center gap-1 px-2.5 py-0.5 bg-slate-900 hover:bg-red-950/80 text-slate-300 hover:text-red-300 rounded border border-slate-800 hover:border-red-900 text-[11px] transition"
              title="Sign out and return to user/password login screen"
            >
              <LogOut className="w-3 h-3 text-red-400" />
              <span className="hidden sm:inline">Sign Out</span>
            </button>
          )}

          {/* Clock */}
          <div className="flex items-center gap-1 font-mono text-slate-300">
            <Clock className="w-3 h-3 text-slate-500" />
            <span>{time}</span>
          </div>
        </div>
      </div>

      {/* Main Workstation Navigation Bar */}
      <div className="px-4 py-2 flex flex-col md:flex-row items-center justify-between gap-3">
        {/* Dedicated Station Identity (Strict Role Lock) */}
        {currentUser.role !== 'admin' ? (
          <div className="flex items-center gap-3 flex-wrap">
            {(() => {
              const currentStation = workstations.find((st) => st.role === currentRole) || workstations[0];
              return (
                <div className="flex items-center gap-2.5 px-3 py-1.5 rounded-xl bg-slate-800/90 border border-teal-500/40 text-teal-300 shadow-sm">
                  <span className="p-1.5 rounded-lg bg-teal-500/20 text-teal-400">
                    {currentStation.icon}
                  </span>
                  <div>
                    <div className="text-xs font-black text-white uppercase tracking-wide flex items-center gap-2">
                      <span>{currentStation.stationName}</span>
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-teal-950 text-teal-300 border border-teal-600/50">
                        <ShieldCheck className="w-3 h-3 text-teal-400" />
                        Dedicated Station
                      </span>
                    </div>
                    <div className="text-[10px] text-slate-400 font-mono">
                      Terminal PC: {currentWorkstation?.name || 'Local PC'} ({currentWorkstation?.roomOrCounter || 'Counter 1'}) • Department: {currentUser.department}
                    </div>
                  </div>
                </div>
              );
            })()}

            <div className="hidden lg:flex items-center gap-1.5 text-[11px] text-slate-400 bg-slate-950/70 px-3 py-1.5 rounded-xl border border-slate-800">
              <Lock className="w-3.5 h-3.5 text-amber-400 shrink-0" />
              <span>
                Access locked to <strong className="text-white capitalize">{currentUser.role}</strong> station. Other hospital computers restricted.
              </span>
            </div>
          </div>
        ) : (
          /* Administrator Oversight Station Switcher */
          <div className="flex items-center gap-1.5 overflow-x-auto w-full md:w-auto pb-1 md:pb-0">
            <span className="text-[11px] font-bold text-amber-400 uppercase tracking-wider flex items-center gap-1 mr-1">
              <Shield className="w-3.5 h-3.5 text-amber-400" />
              Admin Oversight:
            </span>
            {workstations.map((st) => {
              const isActive = currentRole === st.role;
              return (
                <button
                  key={st.role}
                  onClick={() => onRoleChange(st.role)}
                  className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold transition whitespace-nowrap ${
                    isActive
                      ? 'bg-amber-500 text-slate-950 shadow-sm font-bold scale-[1.02]'
                      : 'bg-slate-800/80 text-slate-300 hover:bg-slate-800 hover:text-white'
                  }`}
                >
                  <span>{st.icon}</span>
                  <span>{st.label}</span>
                </button>
              );
            })}
          </div>
        )}

        {/* Current Operator Profile */}
        <div className="relative flex items-center gap-2">
          <div
            onClick={() => setShowUserDropdown(!showUserDropdown)}
            className="flex items-center gap-2.5 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 rounded-lg cursor-pointer transition border border-slate-700"
          >
            <div className="w-6 h-6 rounded-full bg-teal-600 flex items-center justify-center text-xs font-bold text-white uppercase">
              {currentUser.name.charAt(0)}
            </div>
            <div className="text-left">
              <div className="text-xs font-bold text-white flex items-center gap-1">
                <span>{currentUser.name}</span>
                <ChevronDown className="w-3 h-3 text-slate-400" />
              </div>
              <div className="text-[10px] text-teal-400 capitalize">
                {currentUser.role} • {currentUser.department}
              </div>
            </div>
          </div>

          {/* Secure Operator Details & Lock Dropdown (No arbitrary user bypass!) */}
          {showUserDropdown && (
            <div className="absolute right-0 top-12 w-80 bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl p-4 z-50 animate-in fade-in zoom-in-95 duration-100 text-xs">
              <div className="flex items-center gap-3 pb-3 border-b border-slate-800">
                <div className="w-10 h-10 rounded-xl bg-teal-500/20 border border-teal-500/40 flex items-center justify-center text-teal-300 text-sm font-black uppercase">
                  {currentUser.name.charAt(0)}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-bold text-white text-sm truncate">{currentUser.name}</div>
                  <div className="text-[11px] text-teal-400 font-mono">@{currentUser.username}</div>
                  <div className="text-[10px] text-slate-400 truncate">{currentUser.department}</div>
                </div>
              </div>

              <div className="my-3 space-y-2 bg-slate-950/70 p-3 rounded-xl border border-slate-800 text-[11px]">
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Assigned Role:</span>
                  <span className="font-bold text-teal-300 uppercase">{currentUser.role}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Station Terminal:</span>
                  <span className="font-mono text-slate-200">{currentWorkstation?.id || 'WS-LOCAL'}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Session Security:</span>
                  <span className="text-emerald-400 font-medium flex items-center gap-1">
                    <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" /> Station Locked
                  </span>
                </div>
              </div>

              <div className="space-y-2 pt-1">
                <button
                  onClick={() => {
                    setShowUserDropdown(false);
                    onLockScreen?.();
                  }}
                  className="w-full text-left p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white flex items-center gap-2.5 transition font-semibold"
                >
                  <Lock className="w-4 h-4 text-amber-400" />
                  <div className="flex-1">
                    <div>Lock Screen</div>
                    <div className="text-[10px] text-slate-400 font-normal">Require PIN or password to resume session</div>
                  </div>
                </button>

                {onLogout && (
                  <button
                    onClick={() => {
                      setShowUserDropdown(false);
                      onLogout();
                    }}
                    className="w-full text-left p-2.5 rounded-xl bg-red-950/40 hover:bg-red-900/60 border border-red-800/50 text-red-200 hover:text-white flex items-center gap-2.5 transition font-semibold"
                  >
                    <LogOut className="w-4 h-4 text-red-400" />
                    <div className="flex-1">
                      <div className="font-bold">Sign Out / Switch Operator</div>
                      <div className="text-[10px] text-red-300 font-normal">Next staff member must enter their own password</div>
                    </div>
                  </button>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};
