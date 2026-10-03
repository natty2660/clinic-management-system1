import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class DoctorScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;

  const DoctorScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  List<Visit> _queueVisits = [];
  List<Medicine> _medicines = [];
  Visit? _activeVisit;
  bool _isLoading = false;

  // Clinical inputs
  final _chiefComplaintController = TextEditingController(text: 'Persistent cough, low grade fever and general fatigue x 4 days.');
  final _vitalsBpController = TextEditingController(text: '120/80');
  final _vitalsPulseController = TextEditingController(text: '76');
  final _vitalsTempController = TextEditingController(text: '37.8');
  final _vitalsSpo2Controller = TextEditingController(text: '98');
  final _diagnosisController = TextEditingController(text: 'Acute Upper Respiratory Tract Infection (URTI)');

  // Prescription builder
  final List<PrescriptionItem> _prescribedItems = [];
  Medicine? _selectedMedicine;
  final _dosageController = TextEditingController(text: '1 tab TID after meals');
  int _durationDays = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _vitalsBpController.dispose();
    _vitalsPulseController.dispose();
    _vitalsTempController.dispose();
    _vitalsSpo2Controller.dispose();
    _diagnosisController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final visits = await ApiService().getVisits();
    final meds = await ApiService().getMedicines();
    if (mounted) {
      setState(() {
        _queueVisits = visits;
        _medicines = meds;
        if (_activeVisit == null && visits.isNotEmpty) {
          _activeVisit = visits.first;
        }
        if (meds.isNotEmpty) {
          _selectedMedicine = meds.first;
        }
        _isLoading = false;
      });
    }
  }

  void _addPrescriptionItem() {
    if (_selectedMedicine == null) return;

    final qty = _durationDays * 3; // Estimated quantity
    final total = qty * _selectedMedicine!.unitPrice;

    setState(() {
      _prescribedItems.add(
        PrescriptionItem(
          medicineId: _selectedMedicine!.id,
          medicineName: '${_selectedMedicine!.name} (${_selectedMedicine!.strength})',
          dosage: _dosageController.text,
          frequencyPerDay: 3,
          durationDays: _durationDays,
          quantity: qty,
          unitPrice: _selectedMedicine!.unitPrice,
          totalPrice: total,
        ),
      );
    });
  }

  void _completeConsultation() async {
    if (_activeVisit == null) return;

    setState(() => _isLoading = true);

    try {
      if (_prescribedItems.isNotEmpty) {
        final totalRxAmount = _prescribedItems.fold<double>(0.0, (sum, i) => sum + i.totalPrice);
        final rx = Prescription(
          id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
          prescriptionNumber: 'RX-${DateTime.now().year}-${1000 + DateTime.now().millisecond}',
          visitId: _activeVisit!.id,
          patientId: _activeVisit!.patientId,
          patientName: _activeVisit!.patientName,
          patientMrn: _activeVisit!.patientMrn,
          doctorName: widget.currentUser.name,
          items: List.from(_prescribedItems),
          totalAmount: totalRxAmount,
          status: 'prescribed',
        );
        await ApiService().createPrescription(rx);
      }

      _activeVisit!.status = 'completed';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F766E),
          content: Text('Consultation completed & prescription sent to Pharmacy for ${_activeVisit!.patientName}'),
        ),
      );

      setState(() {
        _prescribedItems.clear();
        _queueVisits.removeWhere((v) => v.id == _activeVisit!.id);
        _activeVisit = _queueVisits.isNotEmpty ? _queueVisits.first : null;
      });
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
        title: Row(
          children: [
            const Icon(Icons.medical_services_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            const Text('OPD Doctor PC Consultation Suite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0369A1).withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0284C7)),
              ),
              child: Text(
                'Dr: ${widget.currentUser.name}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF7DD3FC), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : Row(
              children: [
                // Left: Active Queue Sidebar
                Container(
                  width: 280,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(right: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF0F172A),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Waiting Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(10)),
                              child: Text('${_queueVisits.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _queueVisits.length,
                          itemBuilder: (context, index) {
                            final v = _queueVisits[index];
                            final isSelected = _activeVisit?.id == v.id;
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: const Color(0xFF0284C7).withOpacity(0.2),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
                                child: Text('#${v.queueNumber}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(v.patientName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text(v.patientMrn, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                              onTap: () => setState(() => _activeVisit = v),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: Clinical Examination & Prescription Builder
                Expanded(
                  child: _activeVisit == null
                      ? const Center(child: Text('No patient selected from queue', style: TextStyle(color: Color(0xFF94A3B8))))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Patient Banner
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _activeVisit!.patientName,
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                        ),
                                        Text(
                                          'MRN: ${_activeVisit!.patientMrn} | Queue #${_activeVisit!.queueNumber} | Department: ${_activeVisit!.department}',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _completeConsultation,
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: const Text('Complete Consultation & Send Rx'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0284C7),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Vital Signs
                              const Text('Vital Signs & Triage Observations', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildVitalInput('BP (mmHg)', _vitalsBpController),
                                  const SizedBox(width: 8),
                                  _buildVitalInput('Pulse (bpm)', _vitalsPulseController),
                                  const SizedBox(width: 8),
                                  _buildVitalInput('Temp (°C)', _vitalsTempController),
                                  const SizedBox(width: 8),
                                  _buildVitalInput('SpO2 (%)', _vitalsSpo2Controller),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Provisional Diagnosis
                              const Text('Provisional Diagnosis & Clinical Impression', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _diagnosisController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Diagnosis', ''),
                              ),
                              const SizedBox(height: 16),

                              // Electronic Prescription Section
                              const Text('Electronic Pharmacy Prescription Formulary', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Card(
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: DropdownButtonFormField<Medicine>(
                                              value: _selectedMedicine,
                                              dropdownColor: const Color(0xFF1E293B),
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                              decoration: _inputDecoration('Select Formulary Medication', ''),
                                              items: _medicines.map((m) {
                                                return DropdownMenuItem(
                                                  value: m,
                                                  child: Text('${m.name} ${m.strength} (${ApiService.formatCurrency(m.unitPrice)}/unit) [Stock: ${m.currentStock}]'),
                                                );
                                              }).toList(),
                                              onChanged: (v) => setState(() => _selectedMedicine = v),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _dosageController,
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                              decoration: _inputDecoration('Instructions / Dosage', 'e.g. 1 tab TID'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: _addPrescriptionItem,
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('Add Rx'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF14B8A6),
                                              foregroundColor: const Color(0xFF0F172A),
                                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Prescribed Items List
                                      if (_prescribedItems.isNotEmpty)
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _prescribedItems.length,
                                          itemBuilder: (context, idx) {
                                            final item = _prescribedItems[idx];
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(item.medicineName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                  Text(item.dosage, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                                  Text('Qty: ${item.quantity}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                                                  Text(ApiService.formatCurrency(item.totalPrice), style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 12)),
                                                  IconButton(
                                                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                                    onPressed: () => setState(() => _prescribedItems.removeAt(idx)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildVitalInput(String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        decoration: _inputDecoration(label, ''),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }
}
