import 'package:flutter/material.dart';

/// Global app brightness toggle (Mercotrace-style Sun/Moon on onboarding).
final ValueNotifier<ThemeMode> appThemeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);
