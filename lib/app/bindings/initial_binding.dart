import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../database/database.dart';
import '../pages/update/update_controller.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/cache_repository.dart';
import '../repositories/operation_history_repository.dart';
import '../repositories/recent_files_repository.dart';
import '../services/local_image_channel.dart';
import '../services/app_update_platform.dart';
import '../services/app_update_service.dart';

/// 全局依赖绑定，集中注册数据库、平台通道和仓储。
///
/// 设计意图：所有基础设施通过 GetX 延迟创建，页面只依赖 Controller；
/// `fenix` 保证页面释放后再次进入仍能恢复依赖。
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppDatabase>(() => AppDatabase(), fenix: true);
    Get.lazyPut<LocalImageChannel>(() => LocalImageChannel(), fenix: true);
    Get.lazyPut<OperationHistoryRepository>(
      () => OperationHistoryRepository(database: Get.find<AppDatabase>()),
      fenix: true,
    );
    Get.lazyPut<AppSettingsRepository>(
      () => AppSettingsRepository(database: Get.find<AppDatabase>()),
      fenix: true,
    );
    Get.lazyPut<RecentFilesRepository>(
      () => RecentFilesRepository(database: Get.find<AppDatabase>()),
      fenix: true,
    );
    Get.lazyPut<CacheRepository>(
      () => CacheRepository(database: Get.find<AppDatabase>()),
      fenix: true,
    );
    Get.lazyPut<AppUpdatePlatform>(
      () => MethodChannelAppUpdatePlatform(),
      fenix: true,
    );
    Get.lazyPut<AppUpdateService>(
      () => AppUpdateService(platform: Get.find<AppUpdatePlatform>()),
      fenix: true,
    );
    Get.lazyPut<AppUpdateController>(
      () => AppUpdateController(
        service: Get.find<AppUpdateService>(),
        settingsRepository: Get.find<AppSettingsRepository>(),
        automaticChecksEnabled: kReleaseMode,
      ),
      fenix: true,
    );
  }
}
