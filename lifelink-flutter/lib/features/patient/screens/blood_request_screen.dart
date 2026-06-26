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
    try {
      final hospitalRepo = ref.read(hospitalRepositoryProvider);
      final hospitals = await hospitalRepo.getHospitals();
      setState(() => _hospitals = hospitals);
    } catch (_) {}
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBloodGroup == null || _selectedUrgency == null || _selectedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required fields')),
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
        'hospital_id': int.parse(_selectedHospitalId!),
        'is_emergency': _isEmergency,
        'reason': _reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood request submitted successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.03),
                AppTheme.secondaryColor.withOpacity(0.01),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner Card
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.biotech_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blood Support Request',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Specify your requirements and our network will respond immediately.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Card Section: Blood Group
                _buildCardSection(
                  title: 'Required Blood Group',
                  child: _buildBloodGroupSelector(),
                ),
                SizedBox(height: 16.h),

                // Card Section: Quantity
                _buildCardSection(
                  title: 'Quantity (Units)',
                  child: _buildQuantitySelector(),
                ),
                SizedBox(height: 16.h),

                // Card Section: Urgency
                _buildCardSection(
                  title: 'Urgency Level',
                  child: _buildUrgencySelector(),
                ),
                SizedBox(height: 16.h),

                // Card Section: Hospital
                _buildCardSection(
                  title: 'Select Destination Hospital',
                  child: _buildHospitalDropdown(),
                ),
                SizedBox(height: 16.h),

                // Card Section: Reason
                _buildCardSection(
                  title: 'Reason / Special Notes (Optional)',
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Describe the medical reason or requirements',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                    onChanged: (value) => _reason = value,
                  ),
                ),
                SizedBox(height: 16.h),

                // Card Section: Emergency Mode
                _buildEmergencyToggle(),
                SizedBox(height: 32.h),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    backgroundColor: _isEmergency ? AppTheme.error : AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: _isEmergency ? 4 : 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isEmergency ? 'SUBMIT EMERGENCY REQUEST' : 'Submit Request',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface.withOpacity(0.85),
            ),
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Widget _buildBloodGroupSelector() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.1,
      ),
      itemCount: AppConstants.bloodGroups.length,
      itemBuilder: (context, index) {
        final bg = AppConstants.bloodGroups[index];
        final isSelected = _selectedBloodGroup == bg;
        return InkWell(
          onTap: () => setState(() => _selectedBloodGroup = bg),
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[50],
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                bg,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.onSurface.withOpacity(0.75),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              color: _quantity > 1 ? AppTheme.primaryColor : Colors.grey[400],
              size: 28.w,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_quantity',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                'Units',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => setState(() => _quantity++),
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.primaryColor,
              size: 28.w,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencySelector() {
    final urgencyLevels = [
      {'value': 'LOW', 'label': 'Low', 'color': Colors.green},
      {'value': 'MEDIUM', 'label': 'Medium', 'color': Colors.amber[700]!},
      {'value': 'HIGH', 'label': 'High', 'color': Colors.orange[800]!},
      {'value': 'CRITICAL', 'label': 'Critical', 'color': Colors.red[900]!},
    ];

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: urgencyLevels.map((level) {
        final isSelected = _selectedUrgency == level['value'];
        final color = level['color'] as Color;
        return InkWell(
          onTap: () => setState(() => _selectedUrgency = level['value'] as String),
          borderRadius: BorderRadius.circular(12.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.08) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected ? color : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  level['label'] as String,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : AppTheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHospitalDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedHospitalId,
      decoration: InputDecoration(
        labelText: 'Destination Hospital',
        labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
        prefixIcon: const Icon(Icons.local_hospital_outlined),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _hospitals
          .map((h) => DropdownMenuItem(value: h.id.toString(), child: Text(h.name)))
          .toList(),
      onChanged: (value) => setState(() => _selectedHospitalId = value),
      validator: (value) => value == null ? 'Please select a hospital' : null,
    );
  }

  Widget _buildEmergencyToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: _isEmergency ? AppTheme.error.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: _isEmergency ? AppTheme.error.withOpacity(0.5) : Colors.grey[100]!,
          width: _isEmergency ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: _isEmergency ? AppTheme.error.withOpacity(0.1) : Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.crisis_alert_rounded,
              color: _isEmergency ? AppTheme.error : Colors.grey[400],
              size: 24.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Emergency Mode',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: _isEmergency ? AppTheme.error : AppTheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Instantly notify nearby blood donors.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isEmergency,
            onChanged: (value) {
              setState(() {
                _isEmergency = value;
                if (value) {
                  _selectedUrgency = 'CRITICAL';
                }
              });
            },
            activeColor: AppTheme.error,
          ),
        ],
      ),
    );
  }
}
