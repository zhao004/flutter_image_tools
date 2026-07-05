import 'package:get/get.dart';

import '../../repositories/favorite_templates_repository.dart';
import 'favorites_controller.dart';

class FavoritesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FavoritesController>(
      () => FavoritesController(
        repository: Get.find<FavoriteTemplatesRepository>(),
      ),
    );
  }
}
