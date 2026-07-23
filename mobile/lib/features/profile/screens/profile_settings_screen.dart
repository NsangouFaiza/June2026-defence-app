import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../data/models/user_model.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('profile_settings')),
      ),
      body: userAsync.when(
        data: (user) => user != null ? _buildProfile(context, ref, user, localization) : const Center(child: Text('User not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    LocalizationService localization,
  ) {
    final avatarUrl = user.fullProfilePictureUrl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Picture
          Center(
            child: GestureDetector(
              onTap: () => _showProfilePictureOptions(context, ref, user),
              child: Stack(
                children: [
                  Container(
                    width: 120.w,
                    height: 120.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 48.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 48.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20.r,
                      backgroundColor: AppTheme.primaryColor,
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32.h),

          // Personal Information
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localization.translate('personal_information'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => _EditProfileDialog(user: user),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildInfoRow(context, 'User ID', user.role == 'lab_technician' ? 'TECH-2026-${user.id.toString().padLeft(4, '0')}' : 'USER-#${user.id}'),
                  _buildInfoRow(context, localization.translate('full_name'), user.fullName),
                  _buildInfoRow(context, localization.translate('email'), user.email),
                  _buildInfoRow(context, localization.translate('phone'), user.phoneNumber),
                  if (user.role == 'lab_technician' || user.role == 'hospital_staff')
                    _buildInfoRow(context, 'Hospital / Laboratory', 'Central Hospital & Regional Lab'),
                  _buildInfoRow(context, localization.translate('blood_group'), user.bloodGroup ?? 'N/A'),
                  _buildInfoRow(context, localization.translate('gender'), user.gender == 'M' ? 'Male' : (user.gender == 'F' ? 'Female' : 'N/A')),
                  _buildInfoRow(
                    context,
                    localization.translate('date_of_birth'),
                    user.dateOfBirth == null
                        ? 'N/A'
                        : user.dateOfBirth!.toLocal().toString().split(' ')[0],
                  ),
                  _buildInfoRow(context, localization.translate('address'), user.address ?? 'N/A'),
                  _buildInfoRow(context, localization.translate('city'), user.city ?? 'N/A'),
                  _buildInfoRow(context, localization.translate('region'), user.region ?? 'N/A'),
                  _buildInfoRow(
                    context,
                    localization.translate('role'),
                    user.role == 'lab_technician'
                        ? 'Lab Technician'
                        : (user.role == 'hospital_staff' ? 'Hospital Staff' : user.role.toUpperCase()),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Preferences
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localization.translate('preferences'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16.h),
                  SwitchListTile(
                    title: Text(localization.translate('push_notifications')),
                    subtitle: const Text('Receive push notifications'),
                    value: user.notificationPreferences ?? true,
                    onChanged: (value) async {
                      try {
                        await ref.read(authRepositoryProvider).updateProfile({
                          'notification_preferences': value,
                        });
                        ref.invalidate(currentUserProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    title: Text(localization.translate('email_notifications')),
                    subtitle: const Text('Receive email notifications'),
                    value: user.emailNotifications ?? true,
                    onChanged: (value) async {
                      try {
                        await ref.read(authRepositoryProvider).updateProfile({
                          'email_notifications': value,
                        });
                        ref.invalidate(currentUserProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    title: Text(localization.translate('dark_mode')),
                    subtitle: const Text('Enable dark mode'),
                    value: ref.watch(themeModeProvider) == ThemeMode.dark,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).toggleTheme(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Language Selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(localization.translate('language')),
              subtitle: Text(user.language == 'fr' ? 'Français' : 'English'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(localization.translate('language')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English 🇬🇧'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await ref.read(localizationProvider.notifier).changeLanguage('en');
                            await ref.read(authRepositoryProvider).updateProfile({'language': 'en'});
                            ref.invalidate(currentUserProvider);
                          },
                        ),
                        ListTile(
                          title: const Text('Français 🇫🇷'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await ref.read(localizationProvider.notifier).changeLanguage('fr');
                            await ref.read(authRepositoryProvider).updateProfile({'language': 'fr'});
                            ref.invalidate(currentUserProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16.h),

          // Security
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outlined),
                  title: Text(localization.translate('change_password')),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to change password
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: Text(localization.translate('security_settings')),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to security settings
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // Logout Button
          ElevatedButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.invalidate(currentUserProvider);
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(localization.translate('logout')),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfilePictureOptions(BuildContext context, WidgetRef ref, UserModel user) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Photo / Photo de profil',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: const Text('Take Photo / Prendre une photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    _pickAndUploadImage(context, ref, ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                title: const Text('Choose from Gallery / Choisir dans la galerie'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    _pickAndUploadImage(context, ref, ImageSource.gallery);
                  }
                },
              ),
              if (user.profilePicture != null && user.profilePicture!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                  title: const Text('Remove Photo / Supprimer la photo', style: TextStyle(color: AppTheme.error)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _deleteImage(context, ref);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    // Request permissions first
    try {
      if (source == ImageSource.camera) {
        await PermissionService.requestCameraPermission(context);
      } else {
        await PermissionService.requestPhotosPermission(context);
      }
    } catch (_) {}

    messenger.showSnackBar(
      SnackBar(
        content: Text(source == ImageSource.camera ? 'Opening Camera...' : 'Opening Gallery...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked != null) {
        if (context.mounted) {
          await _uploadImage(context, ref, picked);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected.')),
          );
        }
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${source == ImageSource.camera ? "camera" : "gallery"}: ${e.message ?? e.code}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadImage(BuildContext context, WidgetRef ref, XFile file) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading profile photo...')),
        );
      }
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.uploadProfilePicture(file);
      ref.invalidate(currentUserProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteImage(BuildContext context, WidgetRef ref) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.deleteProfilePicture();
      ref.invalidate(currentUserProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove photo: ${e.toString()}')),
        );
      }
    }
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditProfileDialog({required this.user});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _regionController;
  
  String? _selectedGender;
  String? _selectedBloodGroup;
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _addressController = TextEditingController(text: widget.user.address);
    _cityController = TextEditingController(text: widget.user.city);
    _regionController = TextEditingController(text: widget.user.region);
    _selectedGender = widget.user.gender;
    _selectedBloodGroup = widget.user.bloodGroup;
    _selectedDateOfBirth = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedData = {
        'full_name': _fullNameController.text,
        'phone_number': _phoneController.text,
        'gender': _selectedGender,
        'blood_group': _selectedBloodGroup,
        'address': _addressController.text,
        'city': _cityController.text,
        'region': _regionController.text,
        if (_selectedDateOfBirth != null)
          'date_of_birth': _selectedDateOfBirth!.toLocal().toString().split(' ')[0],
      };

      await ref.read(authRepositoryProvider).updateProfile(updatedData);
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return AlertDialog(
      title: Text(localization.translate('edit')),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: localization.translate('full_name'),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: localization.translate('phone'),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: localization.translate('gender'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Male')),
                    DropdownMenuItem(value: 'F', child: Text('Female')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGender = val;
                    });
                  },
                ),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: _selectedBloodGroup,
                  decoration: InputDecoration(
                    labelText: localization.translate('blood_group'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'A+', child: Text('A+')),
                    DropdownMenuItem(value: 'A-', child: Text('A-')),
                    DropdownMenuItem(value: 'B+', child: Text('B+')),
                    DropdownMenuItem(value: 'B-', child: Text('B-')),
                    DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                    DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                    DropdownMenuItem(value: 'O+', child: Text('O+')),
                    DropdownMenuItem(value: 'O-', child: Text('O-')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedBloodGroup = val;
                    });
                  },
                ),
                SizedBox(height: 8.h),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDateOfBirth = pickedDate;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: localization.translate('date_of_birth'),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDateOfBirth == null
                              ? 'Select Date'
                              : _selectedDateOfBirth!.toLocal().toString().split(' ')[0],
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: localization.translate('address'),
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: localization.translate('city'),
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _regionController,
                  decoration: InputDecoration(
                    labelText: localization.translate('region'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(localization.translate('cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(localization.translate('save')),
        ),
      ],
    );
  }
}
