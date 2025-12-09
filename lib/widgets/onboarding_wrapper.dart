import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../screens/onboarding_screen.dart';
import '../screens/first_words_tutorial_screen.dart';
import '../services/session_service.dart';

class OnboardingWrapper extends StatefulWidget {
  final Widget child;

  const OnboardingWrapper({
    super.key,
    required this.child,
  });

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  bool _isLoading = true;
  bool _showOnboarding = false;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      // Get current user ID
      final sessionService = context.read<SessionService>();
      final userId = sessionService.currentUser?.uid;

      if (userId == null) {
        // No user, skip onboarding
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Check per-user onboarding status
      final userOnboardingKey = 'onboarding_completed_$userId';
      final userTutorialKey = 'tutorial_completed_$userId';
      
      final onboardingCompleted = prefs.getBool(userOnboardingKey) ?? false;
      final tutorialCompleted = prefs.getBool(userTutorialKey) ?? false;

      if (mounted) {
        setState(() {
          _showOnboarding = !onboardingCompleted;
          _showTutorial = onboardingCompleted && !tutorialCompleted;
          _isLoading = false;
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onOnboardingComplete() async {
    try {
      final sessionService = context.read<SessionService>();
      final userId = sessionService.currentUser?.uid;

      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed_$userId', true);

      }

      if (mounted) {
        setState(() {
          _showOnboarding = false;
          _showTutorial = true;
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _showOnboarding = false;
          _showTutorial = true;
        });
      }
    }
  }

  Future<void> _onTutorialComplete() async {
    try {
      final sessionService = context.read<SessionService>();
      final userId = sessionService.currentUser?.uid;

      if (userId != null) {

        final prefs = await SharedPreferences.getInstance();
        final success = await prefs.setBool('tutorial_completed_$userId', true);
        
        if (success) {

        } else {

        }
      } else {

      }

      if (mounted) {
        setState(() {
          _showTutorial = false;
        });
      }
    } catch (e) {

      // Hata olsa bile tutorial'ı kapat ki kullanıcı sıkışmasın
      if (mounted) {
        setState(() {
          _showTutorial = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: _onOnboardingComplete,
      );
    }

    if (_showTutorial) {
      return FirstWordsTutorialScreen(
        onComplete: _onTutorialComplete,
      );
    }

    return widget.child;
  }
}
