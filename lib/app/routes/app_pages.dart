import 'package:get/get.dart';

import '../pages/compress/compress_binding.dart';
import '../pages/compress/compress_view.dart';
import '../pages/flip/flip_binding.dart';
import '../pages/flip/flip_view.dart';
import '../pages/history/history_binding.dart';
import '../pages/history/history_view.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/resize/resize_binding.dart';
import '../pages/resize/resize_view.dart';
import '../pages/rotate/rotate_binding.dart';
import '../pages/rotate/rotate_view.dart';
import '../pages/settings/settings_binding.dart';
import '../pages/settings/settings_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: _Paths.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.compress,
      page: () => const CompressView(),
      binding: CompressBinding(),
    ),
    GetPage(
      name: _Paths.history,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: _Paths.flip,
      page: () => const FlipView(),
      binding: FlipBinding(),
    ),
    GetPage(
      name: _Paths.resize,
      page: () => const ResizeView(),
      binding: ResizeBinding(),
    ),
    GetPage(
      name: _Paths.rotate,
      page: () => const RotateView(),
      binding: RotateBinding(),
    ),
    GetPage(
      name: _Paths.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
  ];
}
