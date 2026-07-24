import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Donate Blood, Save Lives',
      description: 'Join thousands of donors who are making a difference in their communities every day. Your donation can save up to 3 lives.',
      icon: Icons.volunteer_activism,
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      title: 'Find Blood Quickly',
      description: 'Search for available blood packs at nearby hospitals and blood banks instantly. Get real-time inventory updates.',
      icon: Icons.local_hospital,
      color: AppTheme.accentColor,
    ),
    OnboardingPage(
      title: 'Connect with Donors Nearby',
      description: 'Find donors in your area, chat directly, and schedule appointments. Build a life-saving community together.',
      icon: Icons.people,
      color: AppTheme.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: EdgeInsets.all(32.w),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Illustration Container
                          Container(
                            width: MediaQuery.of(context).size.height > 700 ? 280.w : 180.w,
                            height: MediaQuery.of(context).size.height > 700 ? 280.w : 180.w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  page.color.withOpacity(0.2),
                                  page.color.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(40.r),
                              boxShadow: [
                                BoxShadow(
                                  color: page.color.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                page.icon,
                                size: MediaQuery.of(context).size.height > 700 ? 140.w : 90.w,
                                color: page.color,
                              ),
                            ),
                          ),
                          SizedBox(height: 48.h),
                          // Title
                          Text(
                            page.title,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onSurface,
                                  height: 1.2,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24.h),
                          // Description
                          Text(
                            page.description,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: _currentPage == index ? 24.w : 12.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppTheme.primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 32.h),
            // Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 18.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) SizedBox(width: 16.w),
                  Expanded(
                    flex: _currentPage > 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_currentPage == _pages.length - 1) {
                          // Navigate to login screen directly
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('has_seen_onboarding', true);
                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/login');
                          }
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
