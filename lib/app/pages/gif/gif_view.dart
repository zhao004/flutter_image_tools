import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../../widgets/tool_task_layout.dart';

/// GIF 任务中心，将生成、拆帧和压缩拆分为独立工作流。
class GifView extends StatelessWidget {
  const GifView({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolTaskHubScaffold(
      title: 'gif.title'.tr,
      destinations: [
        ToolTaskDestination(
          title: 'gif.hub.create.title'.tr,
          description: 'gif.hub.create.description'.tr,
          icon: Icons.gif_box_outlined,
          route: Routes.gifCreate,
        ),
        ToolTaskDestination(
          title: 'gif.hub.frames.title'.tr,
          description: 'gif.hub.frames.description'.tr,
          icon: Icons.burst_mode_outlined,
          route: Routes.gifFrames,
        ),
        ToolTaskDestination(
          title: 'gif.hub.compress.title'.tr,
          description: 'gif.hub.compress.description'.tr,
          icon: Icons.compress,
          route: Routes.gifCompress,
        ),
      ],
    );
  }
}
