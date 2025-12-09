import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wrapper widget that enforces immersive fullscreen mode
/// and removes all MediaQuery padding
class ImmersiveWrapper extends StatefulWidget {
  final Widget child;
  
  const ImmersiveWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ImmersiveWrapper> createState() => _ImmersiveWrapperState();
}

class _ImmersiveWrapperState extends State<ImmersiveWrapper> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceImmersiveMode();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceImmersiveMode();
    }
  }
  
  void _enforceImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Do not remove system padding, so SafeArea can work if needed
    return widget.child;
  }
}
