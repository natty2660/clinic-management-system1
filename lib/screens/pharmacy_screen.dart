import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class PharmacyScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;

  const PharmacyScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Medicine> _medicines = [];
  List<Prescription> _prescriptions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final meds = await ApiService().getMedicines();
    final rxs = await ApiService().getPrescriptions();
    if (mounted) {
      setState(() {
        _medicines = meds;
        _prescriptions = rxs;
        _isLoading = false;
      });
    }
  }

  void _dispensePrescription(Prescription rx) async {
    setState(() => _isLoading = true);
    try {
      await ApiService().dispensePrescription(rx.id);
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text('Prescription ${rx.prescriptionNumber} dispensed & inventory stock deducted successfully!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openStockAdjustmentDialog(Medicine med) {
    final controller = TextEditingController(text: '${med.currentStock}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Adjust Stock: ${med.name}', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${med.currentStock} ${med.dosageForm}s', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6)),
            onPressed: () async {
              final newStock = int.tryParse(controller.text) ?? med.currentStock;
              await ApiService().updateMedicineStock(med.id, newStock);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save Stock', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.local_pharmacy_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text('Central Pharmacy & Dispensary Workstation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309).withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Text(
                'Pharmacist: ${widget.currentUser.name}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFFCD34D), fontWeight: FontWeight.bold),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          labelColor: const Color(0xFFF59E0B),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'Medication Inventory Formulary'),
            Tab(icon: Icon(Icons.assignment_turned_in_rounded, size: 18), text: 'Prescriptions & Dispensing Queue'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInventoryTab(),
                _buildPrescriptionsTab(),
              ],
            ),
    );
  }

  // --- TAB 1: Inventory Catalog ---
  Widget _buildInventoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medicines.length,
      itemBuilder: (context, index) {
        final med = _medicines[index];
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: med.isLowStock ? Colors.redAccent : const Color(0xFF334155)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: med.isLowStock ? Colors.red.withOpacity(0.2) : const Color(0xFFF59E0B).withOpacity(0.2),
              child: Icon(
                Icons.medication_rounded,
                color: med.isLowStock ? Colors.redAccent : const Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(med.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                  child: Text(med.strength, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                ),
                if (med.isLowStock) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('LOW STOCK', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              'Code: ${med.code} | Cat: ${med.category} | Batch: ${med.batchNumber} | Exp: ${med.expiryDate}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${med.currentStock} in stock',
                      style: TextStyle(
                        color: med.isLowStock ? Colors.redAccent : const Color(0xFF34D399),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(ApiService.formatCurrency(med.unitPrice), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF14B8A6), size: 18),
                  tooltip: 'Adjust stock',
                  onPressed: () => _openStockAdjustmentDialog(med),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: Prescriptions Queue ---
  Widget _buildPrescriptionsTab() {
    return _prescriptions.isEmpty
        ? const Center(child: Text('No prescriptions in dispensing queue', style: TextStyle(color: Color(0xFF94A3B8))))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _prescriptions.length,
            itemBuilder: (context, index) {
              final rx = _prescriptions[index];
              final isDispensed = rx.status == 'dispensed';

              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(rx.prescriptionNumber, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text('Patient: ${rx.patientName} (${rx.patientMrn})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDispensed ? const Color(0xFF0F766E).withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rx.status.toUpperCase(),
                              style: TextStyle(
                                color: isDispensed ? const Color(0xFF2DD4BF) : Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Prescribing Doctor: ${rx.doctorName}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      const Divider(color: Color(0xFF334155)),

                      // Items
                      ...rx.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• ${item.medicineName}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Text(item.dosage, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              Text('Qty: ${item.quantity}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
                              Text(ApiService.formatCurrency(item.totalPrice), style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),

                      const Divider(color: Color(0xFF334155)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total: ${ApiService.formatCurrency(rx.totalAmount)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                          if (!isDispensed)
                            ElevatedButton.icon(
                              onPressed: () => _dispensePrescription(rx),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Dispense & Deduct Stock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: const Color(0xFF0F172A),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
