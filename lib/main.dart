import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/reception_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/pharmacy_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpeedHisApp());
}

class SpeedHisApp extends StatelessWidget {
  const SpeedHisApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPEED Hospital Information System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF14B8A6), // Teal 500
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF14B8A6),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
        ),
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      home: const MainAppNavigator(),
    );
  }
}

class MainAppNavigator extends StatefulWidget {
  const MainAppNavigator({Key? key}) : super(key: key);

  @override
  State<MainAppNavigator> createState() => _MainAppNavigatorState();
}

class _MainAppNavigatorState extends State<MainAppNavigator> {
  User? _authenticatedUser;
  UserRole _activeRole = UserRole.cashier;

  void _handleLoginSuccess(User user) {
    setState(() {
      _authenticatedUser = user;
      _activeRole = user.role;
    });
  }

  void _handleLogout() {
    ApiService().logout();
    setState(() {
      _authenticatedUser = null;
    });
  }

  void _switchStationRole(UserRole role) {
    setState(() {
      _activeRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Command 1: At first when user opens the software, ask user name and password
    if (_authenticatedUser == null) {
      return LoginScreen(onLoginSuccess: _handleLoginSuccess);
    }

    // Role-based routing to respective clinical workstations
    Widget currentWorkstationWidget;
    switch (_activeRole) {
      case UserRole.doctor:
        currentWorkstationWidget = DoctorScreen(
          currentUser: _authenticatedUser!,
          onLogout: _handleLogout,
        );
        break;
      case UserRole.pharmacy:
        currentWorkstationWidget = PharmacyScreen(
          currentUser: _authenticatedUser!,
          onLogout: _handleLogout,
        );
        break;
      case UserRole.cashier:
      default:
        currentWorkstationWidget = ReceptionScreen(
          currentUser: _authenticatedUser!,
          onLogout: _handleLogout,
        );
        break;
    }

    return Scaffold(
      body: currentWorkstationWidget,
      bottomNavigationBar: Container(
        height: 48,
        color: const Color(0xFF090D16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded, size: 14, color: Color(0xFF14B8A6)),
                const SizedBox(width: 8),
                Text(
                  'Active Station: ${_activeRole.label}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Switch Station:',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                const SizedBox(width: 8),
                _buildStationSwitchBtn(UserRole.cashier, 'Reception (OPD/IPD)'),
                const SizedBox(width: 6),
                _buildStationSwitchBtn(UserRole.doctor, 'Doctor Suite'),
                const SizedBox(width: 6),
                _buildStationSwitchBtn(UserRole.pharmacy, 'Pharmacy'),
              ],
            ),
            Row(
              children: [
                Text(
                  'Logged in as ${_authenticatedUser!.name} [${_authenticatedUser!.username}]',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _handleLogout,
                  child: const Row(
                    children: [
                      Icon(Icons.power_settings_new_rounded, size: 14, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text('Lock Station', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSwitchBtn(UserRole role, String label) {
    final isActive = _activeRole == role;
    return InkWell(
      onTap: () => _switchStationRole(role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF14B8A6) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
