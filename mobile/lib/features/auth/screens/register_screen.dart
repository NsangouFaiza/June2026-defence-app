import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/role_router.dart';
import '../../../../data/models/hospital_model.dart';
import '../../../../data/repositories/hospital_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _hospitalNameController = TextEditingController();

  int? _selectedHospitalId;
  HospitalModel? _selectedHospital;
  List<HospitalModel> _hospitalSearchResults = [];
  bool _isSearchingHospitals = false;
  bool _showHospitalOverlay = false;

  String? _selectedGender;
  String? _selectedBloodGroup;
  DateTime? _selectedDateOfBirth;
  String? _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _hospitalNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  void _onHospitalSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _hospitalSearchResults = [];
        _showHospitalOverlay = false;
      });
      return;
    }
    setState(() => _isSearchingHospitals = true);
    try {
      final results = await ref
          .read(hospitalRepositoryProvider)
          .searchLiveHealthcareFacilities(query);
      if (mounted) {
        setState(() {
          _hospitalSearchResults = results;
          _showHospitalOverlay = results.isNotEmpty;
          _isSearchingHospitals = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingHospitals = false);
      }
    }
  }

  Future<void> _register() async {
    final localization = ref.read(localizationServiceProvider);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null ||
        _selectedBloodGroup == null ||
        _selectedDateOfBirth == null ||
        _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate('please_fill_fields'))),
      );
      return;
    }

    if (_selectedRole == 'hospital_staff' && _hospitalNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a Hospital Name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final registerData = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'password': _passwordController.text,
        'password_confirm': _confirmPasswordController.text,
        'gender': _selectedGender,
        'date_of_birth': "${_selectedDateOfBirth!.year.toString().padLeft(4, '0')}-${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}-${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}",
        'blood_group': _selectedBloodGroup,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'region': _regionController.text.trim(),
        'role': _selectedRole,
        'language': localization.currentLanguage,
      };

      if (_selectedRole == 'hospital_staff') {
        registerData['hospital_id'] = _selectedHospitalId;
        registerData['hospital_name'] = _hospitalNameController.text.trim();
        registerData['hospital_address'] = _addressController.text.trim();
        registerData['hospital_city'] = _cityController.text.trim();
        registerData['hospital_region'] = _regionController.text.trim();
        registerData['hospital_phone'] = _phoneController.text.trim();
        registerData['hospital_email'] = _emailController.text.trim();
      }

      final res = await authRepo.register(registerData);

      ref.invalidate(currentUserProvider);
      final user = await ref.read(currentUserProvider.future);

      if (user != null && mounted) {
        await ref.read(localizationProvider.notifier).changeLanguage(user.language);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate('registration_success'))),
        );

        final route = user != null ? getDashboardRouteForRole(user.role) : '/home';
        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localization.translate('error')}: ${e.toString()}')),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with illustration (brand consistent)
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40.r),
                          bottomRight: Radius.circular(40.r),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 20.h),
                          // Healthcare logo
                          Container(
                            width: 120.w,
                            height: 120.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: EdgeInsets.all(12.w),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'LifeLink',
                            style: TextStyle(
                              fontSize: 36.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            localization.translate('tagline'),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12.h,
                      left: 12.w,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        localization.translate('create_account'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        localization.translate('select_role_subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                
                // Role Selection Cards
                Column(
                  children: [
                    _buildRoleCard(
                      icon: Icons.person,
                      title: localization.translate('role_patient_title'),
                      description: localization.translate('role_patient_desc'),
                      value: 'patient',
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(height: 12.h),
                    _buildRoleCard(
                      icon: Icons.volunteer_activism,
                      title: localization.translate('role_donor_title'),
                      description: localization.translate('role_donor_desc'),
                      value: 'donor',
                      color: AppTheme.success,
                    ),
                    SizedBox(height: 12.h),
                    _buildRoleCard(
                      icon: Icons.local_hospital,
                      title: localization.translate('role_hospital_title'),
                      description: localization.translate('role_hospital_desc'),
                      value: 'hospital_staff',
                      color: AppTheme.accentColor,
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                if (_selectedRole == 'hospital_staff') ...[
                  _buildSectionHeader('Hospital Information / Informations de l\'Hôpital'),
                  SizedBox(height: 6.h),
                  Text(
                    'Search for a real hospital/clinic in Cameroon (e.g. HGOPY, CHU, CMA, HCY, HGY, HGD, HLD...) or write a new hospital name manually.',
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _hospitalNameController,
                    decoration: InputDecoration(
                      labelText: 'Hospital Name / Nom de l\'hôpital',
                      prefixIcon: const Icon(Icons.local_hospital_outlined),
                      hintText: 'Type acronym or name (e.g. HGOPY, CHU, Laquintinie...)',
                      suffixIcon: _isSearchingHospitals
                          ? const UnconstrainedBox(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _hospitalNameController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _hospitalNameController.clear();
                                    setState(() {
                                      _selectedHospitalId = null;
                                      _selectedHospital = null;
                                      _hospitalSearchResults = [];
                                      _showHospitalOverlay = false;
                                    });
                                  },
                                )
                              : null,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _selectedHospitalId = null;
                        _selectedHospital = null;
                      });
                      _onHospitalSearchChanged(val);
                    },
                    validator: (value) {
                      if (_selectedRole == 'hospital_staff' && (value == null || value.trim().isEmpty)) {
                        return 'Please enter or select a hospital';
                      }
                      return null;
                    },
                  ),

                  // Search Suggestions Overlay List
                  if (_showHospitalOverlay && _hospitalSearchResults.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Container(
                      constraints: BoxConstraints(maxHeight: 220.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        itemCount: _hospitalSearchResults.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final h = _hospitalSearchResults[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.location_city,
                              color: AppTheme.primaryColor,
                              size: 20.w,
                            ),
                            title: Text(
                              h.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                            ),
                            subtitle: Text(
                              '${h.city ?? ''} ${h.region != null ? "(${h.region})" : ""}',
                              style: TextStyle(fontSize: 11.sp),
                            ),
                            trailing: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: h.isSubscriptionActive
                                    ? AppTheme.success.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                h.isSubscriptionActive ? 'Subscribed' : 'Requires Payment',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: h.isSubscriptionActive ? AppTheme.success : Colors.orange[800],
                                ),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedHospital = h;
                                _selectedHospitalId = (h.id < 9000) ? h.id : null;
                                _hospitalNameController.text = h.name;
                                if (h.address != null && h.address!.isNotEmpty) {
                                  _addressController.text = h.address!;
                                }
                                if (h.city != null && h.city!.isNotEmpty) {
                                  _cityController.text = h.city!;
                                }
                                if (h.region != null && h.region!.isNotEmpty) {
                                  _regionController.text = h.region!;
                                }
                                _showHospitalOverlay = false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  // Selected Hospital Subscription Badge
                  if (_selectedHospital != null) ...[
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: _selectedHospital!.isSubscriptionActive
                            ? AppTheme.success.withOpacity(0.08)
                            : Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: _selectedHospital!.isSubscriptionActive
                              ? AppTheme.success.withOpacity(0.4)
                              : Colors.amber.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedHospital!.isSubscriptionActive
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: _selectedHospital!.isSubscriptionActive
                                ? AppTheme.success
                                : Colors.amber[800],
                            size: 20.w,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _selectedHospital!.isSubscriptionActive
                                  ? 'Active Paid Subscription: You can continue registration and access the app directly.'
                                  : 'No Active Subscription: Registration will redirect to the 25 FCFA/mo subscription payment page.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: _selectedHospital!.isSubscriptionActive
                                    ? AppTheme.success
                                    : Colors.amber[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 20.h),
                ],
                
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: localization.currentLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Language / Langue',
                    prefixIcon: Icon(Icons.language_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                    DropdownMenuItem(value: 'fr', child: Text('Français 🇫🇷')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(localizationProvider.notifier).changeLanguage(value);
                    }
                  },
                ),
                SizedBox(height: 24.h),
                
                // Personal Information Section
                _buildSectionHeader(localization.translate('personal_information')),
                SizedBox(height: 16.h),
                
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: localization.translate('full_name'),
                    prefixIcon: const Icon(Icons.person_outlined),
                    hintText: localization.translate('enter_full_name'),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localization.translate('please_enter_full_name');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: localization.translate('gender'),
                          prefixIcon: const Icon(Icons.person_outlined),
                        ),
                        items: [
                          DropdownMenuItem(value: 'M', child: Text(localization.translate('male'))),
                          DropdownMenuItem(value: 'F', child: Text(localization.translate('female'))),
                        ],
                        onChanged: (value) => setState(() => _selectedGender = value),
                        validator: (value) => value == null ? localization.translate('please_select_gender') : null,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: localization.translate('date_of_birth'),
                            prefixIcon: const Icon(Icons.cake_outlined),
                          ),
                          child: Text(
                            _selectedDateOfBirth == null
                                ? localization.translate('select_dob')
                                : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: localization.translate('blood_group'),
                    prefixIcon: const Icon(Icons.bloodtype_outlined),
                  ),
                  items: AppConstants.bloodGroups
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBloodGroup = value),
                  validator: (value) => value == null ? localization.translate('please_select_blood_group') : null,
                ),
                SizedBox(height: 24.h),
                
                // Contact Information Section
                _buildSectionHeader(localization.translate('contact_information')),
                SizedBox(height: 16.h),
                
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: localization.translate('phone_number'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                    hintText: localization.translate('enter_phone'),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localization.translate('please_enter_phone');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: localization.translate('email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    hintText: localization.translate('enter_email'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localization.translate('please_enter_email');
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return localization.translate('please_enter_valid_email');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: localization.translate('address'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    hintText: localization.translate('enter_address'),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localization.translate('please_enter_address');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: localization.translate('city'),
                          prefixIcon: const Icon(Icons.location_city_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localization.translate('required');
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextFormField(
                        controller: _regionController,
                        decoration: InputDecoration(
                          labelText: localization.translate('region'),
                          prefixIcon: const Icon(Icons.map_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localization.translate('required');
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                
                // Password Section
                _buildSectionHeader(localization.translate('security')),
                SizedBox(height: 16.h),
                
                TextFormField(
                  controller: _passwordController,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: localization.translate('password'),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    hintText: localization.translate('create_password'),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localization.translate('please_enter_password');
                    }
                    if (value.length < 8) {
                      return localization.translate('password_length_error');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _confirmPasswordController,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: localization.translate('confirm_password'),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    hintText: localization.translate('confirm_your_password'),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return localization.translate('passwords_do_not_match');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32.h),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
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
                      : Text(localization.translate('register')),
                ),
                SizedBox(height: 16.h),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      localization.translate('already_have_account'),
                      style: TextStyle(color: AppTheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(localization.translate('login')),
                    ),
                  ],
                ),
                    ],
                  ),
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

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedRole == value;
    return InkWell(
      onTap: () => setState(() => _selectedRole = value),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
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
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28.w,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 24.w,
              ),
          ],
        ),
      ),
    );
  }
}
