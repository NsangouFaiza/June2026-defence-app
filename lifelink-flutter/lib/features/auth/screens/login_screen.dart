import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../core/utils/role_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final localization = ref.read(localizationServiceProvider);
    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      ref.invalidate(currentUserProvider);
      final user = await ref.read(currentUserProvider.future);
      if (user != null && mounted) {
        await ref.read(localizationProvider.notifier).changeLanguage(user.language);
      }

      if (mounted) {
        final route = user != null ? getDashboardRouteForRole(user.role) : '/home';
        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (errStr.contains('SUBSCRIPTION_EXPIRED') || errStr.toLowerCase().contains('subscription is inactive') || errStr.toLowerCase().contains('renew your subscription')) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Subscription Expired')),
                ],
              ),
              content: const Text(
                'Your hospital subscription has expired or been deactivated. Please renew the monthly subscription (25 FCFA/month) to access the application.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushNamed('/hospital-subscription-payment');
                  },
                  child: const Text('Renew Subscription'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${localization.translate('error')}: ${e.toString()}')),
          );
        }
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with illustration
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
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              // Login Form
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        localization.translate('welcome_back'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        localization.translate('sign_in_to_continue'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      DropdownButtonFormField<String>(
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
                      SizedBox(height: 32.h),
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
                      SizedBox(height: 16.h),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: localization.translate('password'),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          hintText: localization.translate('enter_password'),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
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
                      SizedBox(height: 8.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/forgot-password');
                          },
                          child: Text(localization.translate('forgot_password')),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
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
                            : Text(localization.translate('login')),
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            localization.translate('dont_have_account'),
                            style: TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/register');
                            },
                            child: Text(localization.translate('register')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}
