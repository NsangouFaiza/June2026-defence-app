import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/request_repository.dart';
import '../../../../data/repositories/hospital_repository.dart';
import '../../../../data/models/hospital_model.dart';
import '../../../../core/constants/app_constants.dart';

class BloodRequestScreen extends ConsumerStatefulWidget {
  const BloodRequestScreen({super.key});

  @override
  ConsumerState<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends ConsumerState<BloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBloodGroup;
  int _quantity = 1;
  String? _selectedUrgency;
  String? _selectedHospitalId;
  String? _reason;
  bool _isEmergency = false;
  bool _isLoading = false;
  List<HospitalModel> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    final hospitalRepo = ref.read(hospitalRepositoryProvider);
    final hospitals = await hospitalRepo.getHospitals();
    setState(() => _hospitals = hospitals);
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBloodGroup == null || _selectedUrgency == null || _selectedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final requestRepo = ref.read(requestRepositoryProvider);
      await requestRepo.createRequest({
        'blood_group': _selectedBloodGroup,
        'quantity': _quantity,
        'urgency': _selectedUrgency,
        'hospital': int.parse(_selectedHospitalId!),
        'is_emergency': _isEmergency,
        'reason': _reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blood request submitted successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(localization.translate('request_blood')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Illustration
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.secondaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64.w,
                        height: 64.w,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          Icons.bloodtype,
                          color: AppTheme.primaryColor,
                          size: 32.w,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Blood',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Fill in the details below to request blood',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                
                // Blood Group Selection
                _buildSectionHeader('Blood Group'),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  value: _selectedBloodGroup,
                  decoration: InputDecoration(
                    labelText: 'Select Blood Group',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                    hintText: 'Choose blood type',
                  ),
                  items: AppConstants.bloodGroups
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBloodGroup = value),
                  validator: (value) => value == null ? 'Please select blood group' : null,
                ),
                SizedBox(height: 24.h),
                
                // Quantity Selection
                _buildSectionHeader('Quantity'),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Units Required',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: Icon(Icons.remove_circle_outline),
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(
                            width: 40.w,
                            child: Text(
                              '$_quantity',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _quantity++),
                            icon: Icon(Icons.add_circle_outline),
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                
                // Urgency Selection
                _buildSectionHeader('Urgency Level'),
                SizedBox(height: 12.h),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12.w,
                  crossAxisSpacing: 12.w,
                  childAspectRatio: 2.5,
                  children: [
                    _buildUrgencyCard('LOW', 'Low', Colors.green),
                    _buildUrgencyCard('MEDIUM', 'Medium', Colors.orange),
                    _buildUrgencyCard('HIGH', 'High', Colors.red),
                    _buildUrgencyCard('CRITICAL', 'Critical', Colors.purple),
                  ],
                ),
                SizedBox(height: 24.h),
                
                // Hospital Selection
                _buildSectionHeader('Hospital'),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  value: _selectedHospitalId,
                  decoration: InputDecoration(
                    labelText: 'Select Hospital',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                    hintText: 'Choose hospital',
                  ),
                  items: _hospitals
                      .map((h) => DropdownMenuItem(value: h.id.toString(), child: Text(h.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedHospitalId = value),
                  validator: (value) => value == null ? 'Please select a hospital' : null,
                ),
                SizedBox(height: 24.h),
                
                // Reason
                _buildSectionHeader('Reason (Optional)'),
                SizedBox(height: 12.h),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Additional details',
                    prefixIcon: Icon(Icons.description_outlined),
                    hintText: 'Provide any additional information',
                  ),
                  maxLines: 3,
                  onChanged: (value) => _reason = value,
                ),
                SizedBox(height: 24.h),
                
                // Emergency Toggle
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _isEmergency ? AppTheme.error.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: _isEmergency ? AppTheme.error : Colors.grey[300]!,
                      width: _isEmergency ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emergency,
                        color: _isEmergency ? AppTheme.error : Colors.grey[400],
                        size: 24.w,
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localization.translate('emergency'),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              'Mark as emergency request',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isEmergency,
                        onChanged: (value) => setState(() => _isEmergency = value),
                        activeColor: AppTheme.error,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                
                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(localization.translate('submit')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildUrgencyCard(String value, String label, Color color) {
    final isSelected = _selectedUrgency == value;
    return InkWell(
      onTap: () => setState(() => _selectedUrgency = value),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? color : AppTheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
