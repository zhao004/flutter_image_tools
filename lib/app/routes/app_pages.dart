import 'package:get/get.dart';

import '../pages/base64/base64_binding.dart';
import '../pages/base64/base64_view.dart';
import '../pages/cache/cache_binding.dart';
import '../pages/cache/cache_view.dart';
import '../pages/color_picker/color_picker_binding.dart';
import '../pages/color_picker/color_picker_view.dart';
import '../pages/compress/compress_binding.dart';
import '../pages/compress/compress_view.dart';
import '../pages/convert/convert_binding.dart';
import '../pages/convert/convert_view.dart';
import '../pages/crop/crop_binding.dart';
import '../pages/crop/crop_view.dart';
import '../pages/filter/filter_binding.dart';
import '../pages/filter/filter_view.dart';
import '../pages/flip/flip_binding.dart';
import '../pages/flip/flip_view.dart';
import '../pages/grid/grid_binding.dart';
import '../pages/grid/grid_view.dart';
import '../pages/history/history_binding.dart';
import '../pages/history/history_view.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/merge/merge_binding.dart';
import '../pages/merge/merge_view.dart';
import '../pages/resize/resize_binding.dart';
import '../pages/resize/resize_view.dart';
import '../pages/rotate/rotate_binding.dart';
import '../pages/rotate/rotate_view.dart';
import '../pages/settings/settings_binding.dart';
import '../pages/settings/settings_view.dart';
import '../pages/watermark/watermark_binding.dart';
import '../pages/watermark/watermark_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: _Paths.base64,
      page: () => const Base64View(),
      binding: Base64Binding(),
    ),
    GetPage(
      name: _Paths.cache,
      page: () => const CacheView(),
      binding: CacheBinding(),
    ),
    GetPage(
      name: _Paths.colorPicker,
      page: () => const ColorPickerView(),
      binding: ColorPickerBinding(),
    ),
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
      name: _Paths.convert,
      page: () => const ConvertView(),
      binding: ConvertBinding(),
    ),
    GetPage(
      name: _Paths.crop,
      page: () => const CropView(),
      binding: CropBinding(),
    ),
    GetPage(
      name: _Paths.filter,
      page: () => const FilterView(),
      binding: FilterBinding(),
    ),
    GetPage(
      name: _Paths.grid,
      page: () => const GridView(),
      binding: GridBinding(),
    ),
    GetPage(
      name: _Paths.history,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: _Paths.merge,
      page: () => const MergeView(),
      binding: MergeBinding(),
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
    GetPage(
      name: _Paths.watermark,
      page: () => const WatermarkView(),
      binding: WatermarkBinding(),
    ),
  ];
}
