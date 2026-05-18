import 'package:flutter/material.dart';
import '../di/injection.dart';
import 'auth_service.dart';
import 'login_bottom_sheet.dart';

class AuthGuard {
  /// Evaluates if the current user is authenticated.
  /// 
  /// If they are, it synchronously executes [action].
  /// If they are in Guest Mode, it intercepts the call, triggers the premium
  /// login bottom sheet, and executes [action] automatically upon successful login.
  static void run(BuildContext context, VoidCallback action) {
    final isAuthenticated = sl<AuthService>().isAuthenticated;
    if (isAuthenticated) {
      action();
    } else {
      LoginBottomSheet.show(context, onLoginSuccess: action);
    }
  }
}
