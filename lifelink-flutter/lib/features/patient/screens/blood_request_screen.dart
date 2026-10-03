import '../widgets/check_blood_availability_dialog.dart';
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
import '../../../../widgets/lifelink_app_bar.dart';

class BloodRequestScreen extends ConsumerStatefulWidget {
  const BloodRequestScreen({super.key});

  @override
  ConsumerState<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends ConsumerState<BloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBloodGroup;
  int _quantity = 1;
  String _urgencyLevel = 'MEDIUM';
  String _fulfillmentType = 'DIRECT_DONATION';
  String? _selectedHospitalId;
  String? _selectedHospitalName;
  String? _reason;
  bool _isEmergency = false;
  String get _selectedUrgency => _urgencyLevel;
  set _selectedUrgency(String value) => _urgencyLevel = value;
  final _patientNameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _notesController = TextEditingController();


  List<HospitalModel> _hospitals = [];
  bool _isLoadingHospitals = true;
  bool _isLoading = false;

  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      _argsLoaded = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['hospital_id'] != null) {
          _selectedHospitalId = args['hospital_id'].toString();
        }
        if (args['hospital_name'] != null) {
          _selectedHospitalName = args['hospital_name'].toString();
          _hospitalController.text = _selectedHospitalName!;
        }
        if (args['blood_group'] != null) {
          _selectedBloodGroup = args['blood_group'].toString();
        }
        if (args['quantity'] != null) {
          _quantity = args['quantity'] as int;
        }
        if (args['fulfillment_type'] != null) {
          _fulfillmentType = args['fulfillment_type'].toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _hospitalController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    try {
      final repo = ref.read(hospitalRepositoryProvider);
      final list = await repo.getHospitals();
      if (mounted) {
        setState(() {
          _hospitals = list;
          _isLoadingHospitals = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHospitals = false);
      }
    }
  }

  Future<void> _submitRequest() async {
    final localization = ref.read(localizationServiceProvider);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate('select_blood_group_error') ?? 'Please select a blood group')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      final mappedUrgency = (_urgencyLevel == 'NORMAL') ? 'MEDIUM' : _urgencyLevel;
      final requestData = <String, dynamic>{
        'blood_group': _selectedBloodGroup,
        'quantity': _quantity,
        'urgency': mappedUrgency,
        'urgency_level': mappedUrgency,
        'fulfillment_type': _fulfillmentType == 'DONOR_DISPATCH' ? 'DIRECT_DONATION' : _fulfillmentType,
        'reason': _reason ?? '',
        'notes': _notesController.text.trim(),
        'is_emergency': _isEmergency,
        if (_selectedHospitalId != null) 'hospital_id': int.parse(_selectedHospitalId!),
        if (_selectedHospitalName != null) 'hospital_name': _selectedHospitalName,
      };

      await repo.createBloodRequest(requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.translate('request_submitted_success') ?? 'Blood request created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating request: $e'),
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
      appBar: LifeLinkAppBar(
        title: localization.translate('request_blood'),
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
                  title: 'Destination Hospital (Optional)',
                  action: TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => CheckBloodAvailabilityDialog(
                        initialBloodGroup: _selectedBloodGroup,
                        initialQuantity: _quantity,
                        onSelectHospital: (h) {
                          setState(() {
                            _selectedHospitalId = h['hospital_id'].toString();
                            _selectedHospitalName = h['hospital_name'];
                            _hospitalController.text = h['hospital_name'] ?? '';
                            _fulfillmentType = 'INVENTORY';
                            if (h['blood_group'] != null) {
                              _selectedBloodGroup = h['blood_group'];
                            }
                          });
                        },
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: Text(
                      'Check Stock',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
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

  Widget _buildCardSection({required String title, required Widget child, Widget? action}) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface.withOpacity(0.85),
                  ),
                ),
              ),
              if (action != null) ...[
                SizedBox(width: 8.w),
                action,
              ],
            ],
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
    if (_isLoadingHospitals) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12.w),
            Text(
              'Loading hospitals...',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
          ],
        ),
      );
    }

    final validIds = _hospitals.map((h) => h.id.toString()).toSet();
    final effectiveValue = (_selectedHospitalId != null && validIds.contains(_selectedHospitalId))
        ? _selectedHospitalId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          isExpanded: true,
          value: effectiveValue,
          decoration: InputDecoration(
            labelText: 'Preferred Hospital (Optional)',
            labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            hintText: 'Any Eligible Hospital (Network Broadcast)',
            hintStyle: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.local_hospital_outlined),
            suffixIcon: _selectedHospitalId != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: 'Clear selection',
                    onPressed: () {
                      setState(() {
                        _selectedHospitalId = null;
                        _selectedHospitalName = null;
                        _hospitalController.clear();
                      });
                    },
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Any Available Hospital (Network Wide)',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ..._hospitals.map((h) => DropdownMenuItem<String?>(
                  value: h.id.toString(),
                  child: Text(
                    h.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedHospitalId = value;
              if (value != null) {
                final match = _hospitals.where((h) => h.id.toString() == value);
                _selectedHospitalName = match.isNotEmpty ? match.first.name : null;
                _hospitalController.text = _selectedHospitalName ?? '';
              } else {
                _selectedHospitalName = null;
                _hospitalController.clear();
              }
            });
          },
          validator: null,
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 14.sp, color: Colors.grey[500]),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                _selectedHospitalId == null
                    ? 'No specific hospital selected. Any eligible hospital in the LifeLink network can accept and fulfill this request.'
                    : 'Request will be directed to $_selectedHospitalName.',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], height: 1.3),
              ),
            ),
          ],
        ),
      ],
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
