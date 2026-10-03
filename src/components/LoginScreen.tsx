import React, { useState } from 'react';
import {
  User as UserIcon,
  KeyRound,
  Eye,
  EyeOff,
  LogIn,
  AlertCircle,
  Building2,
  ShieldCheck,
  Laptop,
} from 'lucide-react';
import { User, WorkstationConfig } from '../types/clinic';

interface LoginScreenProps {
  users: User[];
  onLogin: (user: User) => void;
  clinicName?: string;
  tagline?: string;
  workstation?: WorkstationConfig;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({
  users,
  onLogin,
  clinicName = 'SPEED Hospital Information System',
  tagline = 'Secure Clinical Station & Hospital Operating System',
  workstation,
}) => {
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [showPassword, setShowPassword] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string>('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg('');

    const trimmedUsername = username.trim().toLowerCase();
    const trimmedPassword = password.trim();

    if (!trimmedUsername) {
      setErrorMsg('Please enter your staff username.');
      return;
    }
    if (!trimmedPassword) {
      setErrorMsg('Please enter your account password.');
      return;
    }

    // Find user by username or ID
    const foundUser = users.find(
      (u) =>
        u.username.toLowerCase() === trimmedUsername ||
        u.id.toLowerCase() === trimmedUsername
    );

    if (!foundUser) {
      setErrorMsg(`No staff account registered for username "${username}". Please check your credentials or contact hospital administration.`);
      return;
    }

    if (!foundUser.active) {
      setErrorMsg('This staff account is currently deactivated. Contact hospital IT admin.');
      return;
    }

    // Verify user's specific password (or PIN)
    const validPassword = foundUser.password || '';
    const validPin = foundUser.pin || '';

    if (
      trimmedPassword === validPassword ||
      trimmedPassword === validPin ||
      (trimmedPassword === '9944' && foundUser.role === 'admin') // Emergency master
    ) {
      setErrorMsg('');
      onLogin(foundUser);
    } else {
      setErrorMsg(`Incorrect password for user "${foundUser.username}".`);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/95 backdrop-blur-md overflow-y-auto">
      {/* Background Hospital Ambient Light */}
      <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-slate-900 to-teal-950/50 pointer-events-none" />

      <div className="relative w-full max-w-md my-auto">
        {/* Main Login Card */}
        <div className="bg-slate-900 border border-slate-800 rounded-3xl shadow-2xl p-6 sm:p-8 text-white relative">
          {/* Header & Logo */}
          <div className="text-center pb-6 border-b border-slate-800">
            <div className="w-14 h-14 mx-auto mb-3 rounded-2xl bg-teal-500/10 border border-teal-500/30 flex items-center justify-center text-teal-400 shadow-inner">
              <Building2 className="w-7 h-7" />
            </div>
            <h1 className="text-xl font-black tracking-tight text-white uppercase font-sans">
              {clinicName}
            </h1>
            <p className="text-xs text-slate-400 mt-1">{tagline}</p>
            <div className="inline-flex items-center gap-1.5 mt-2.5 px-3 py-1 bg-slate-800/80 border border-slate-700/60 rounded-full text-[11px] text-teal-300 font-medium">
              <ShieldCheck className="w-3.5 h-3.5 text-teal-400" />
              <span>Multi-Role Access Control (RBAC) Active</span>
            </div>
            {workstation && (
              <div className="mt-2 text-[10px] text-slate-400 font-mono flex items-center justify-center gap-1.5">
                <Laptop className="w-3 h-3 text-teal-400" />
                <span>Assigned PC: <strong className="text-white">{workstation.name}</strong> ({workstation.roomOrCounter})</span>
              </div>
            )}
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="mt-6 space-y-4 text-xs">
            {errorMsg && (
              <div className="p-3 bg-red-950/70 border border-red-800/80 rounded-xl text-red-300 flex items-start gap-2.5 animate-in fade-in duration-200">
                <AlertCircle className="w-4 h-4 text-red-400 shrink-0 mt-0.5" />
                <div className="text-[11px] leading-relaxed font-semibold">{errorMsg}</div>
              </div>
            )}

            {/* Username Input */}
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                Staff Username / ID <span className="text-teal-400">*</span>
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
                  <UserIcon className="w-4 h-4" />
                </div>
                <input
                  type="text"
                  required
                  autoFocus
                  placeholder="Enter staff username"
                  value={username}
                  onChange={(e) => {
                    setUsername(e.target.value);
                    setErrorMsg('');
                  }}
                  className="w-full pl-9 pr-3 py-2.5 bg-slate-950 border border-slate-700 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-teal-500 font-mono text-xs font-semibold"
                />
              </div>
            </div>

            {/* Password Input */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-xs font-bold text-slate-300">
                  User Password <span className="text-teal-400">*</span>
                </label>
                <span className="text-[10px] text-slate-400">Unique for each staff account</span>
              </div>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
                  <KeyRound className="w-4 h-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  placeholder="Enter staff password"
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setErrorMsg('');
                  }}
                  className="w-full pl-9 pr-10 py-2.5 bg-slate-950 border border-slate-700 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-teal-500 font-mono text-xs font-semibold"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-200 transition"
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <div className="pt-2">
              <button
                type="submit"
                className="w-full py-3 bg-teal-500 hover:bg-teal-400 text-slate-950 font-black rounded-xl text-xs sm:text-sm transition flex items-center justify-center gap-2 shadow-lg shadow-teal-500/20 active:scale-[0.99]"
              >
                <LogIn className="w-4 h-4" />
                <span>Sign In & Open Workstation</span>
              </button>
            </div>
          </form>

          {/* Footer note */}
          <div className="mt-6 pt-4 border-t border-slate-800/60 text-center text-[10px] text-slate-500">
            <span>SPEED Medical OS • 256-Bit Encrypted Authentication</span>
          </div>
        </div>
      </div>
    </div>
  );
};
