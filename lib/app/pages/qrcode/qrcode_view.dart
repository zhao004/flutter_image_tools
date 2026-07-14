import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../../widgets/tool_task_layout.dart';

/// 二维码任务中心，将生成和识别放入不同页面。
class QrcodeView extends StatelessWidget {
  const QrcodeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolTaskHubScaffold(
      title: 'qrcode.title'.tr,
      destinations: [
        ToolTaskDestination(
          title: 'qrcode.hub.generate.title'.tr,
          description: 'qrcode.hub.generate.description'.tr,
          icon: Icons.qr_code_2,
          route: Routes.qrcodeGenerate,
        ),
        ToolTaskDestination(
          title: 'qrcode.hub.scan.title'.tr,
          description: 'qrcode.hub.scan.description'.tr,
          icon: Icons.document_scanner_outlined,
          route: Routes.qrcodeScan,
        ),
      ],
    );
  }
}
