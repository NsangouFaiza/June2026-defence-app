import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48.h),
              Icon(
                Icons.language,
                size: 80.w,
                color: AppTheme.primaryColor,
              ),
              SizedBox(height: 24.h),
              Text(
                localization.translate('select_language'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48.h),
              _buildLanguageCard(
                context,
                ref,
                'English',
                '🇬🇧',
                'en',
              ),
              SizedBox(height: 16.h),
              _buildLanguageCard(
                context,
                ref,
                'Français',
                '🇫🇷',
                'fr',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    WidgetRef ref,
    String language,
    String flag,
    String languageCode,
  ) {
    final localization = ref.watch(localizationServiceProvider);
    final isSelected = localization.currentLanguage == languageCode;

    return Card(
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: Text(
          flag,
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(
          language,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primaryColor : null,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
            : null,
        onTap: () {
          ref.read(localizationProvider.notifier).changeLanguage(languageCode);
          Navigator.of(context).pushReplacementNamed('/login');
        },
      ),
    );
  }
}
