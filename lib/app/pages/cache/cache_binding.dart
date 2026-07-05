import 'package:get/get.dart';

import '../../repositories/cache_repository.dart';
import 'cache_controller.dart';

class CacheBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CacheController>(
      () => CacheController(cacheRepository: Get.find<CacheRepository>()),
    );
  }
}
