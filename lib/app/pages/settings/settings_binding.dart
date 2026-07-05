import 'package:get/get.dart';

import '../../repositories/app_settings_repository.dart';
import 'settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsController>(
      () => SettingsController(
        settingsRepository: Get.find<AppSettingsRepository>(),
      ),
    );
  }
}
