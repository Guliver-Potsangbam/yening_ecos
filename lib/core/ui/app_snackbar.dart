import 'package:flutter/material.dart';

class AppSnackBar {
  AppSnackBar._();

  static void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static void showComingSoon(BuildContext context, String feature) {
    showMessage(context, '$feature will be available soon.');
  }
}
