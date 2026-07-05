import 'package:get/get.dart';

/// 首页状态控制器，负责维护首页计数状态。
///
/// 当前只包含本地响应式计数。没有资源订阅或异步加载，因此不覆盖
/// 生命周期方法，避免保留无意义的空实现。
class HomeController extends GetxController {
  final count = 0.obs;

  void increment() => count.value++;
}
