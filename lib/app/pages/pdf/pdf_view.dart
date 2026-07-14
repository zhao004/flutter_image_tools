import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../../widgets/tool_task_layout.dart';

/// PDF 任务中心，将不同输入类型的转换流程拆分到独立页面。
class PdfView extends StatelessWidget {
  const PdfView({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolTaskHubScaffold(
      title: 'pdf.title'.tr,
      destinations: [
        ToolTaskDestination(
          title: 'pdf.hub.create.title'.tr,
          description: 'pdf.hub.create.description'.tr,
          icon: Icons.picture_as_pdf_outlined,
          route: Routes.pdfImagesToPdf,
        ),
        ToolTaskDestination(
          title: 'pdf.hub.export.title'.tr,
          description: 'pdf.hub.export.description'.tr,
          icon: Icons.collections_outlined,
          route: Routes.pdfToImages,
        ),
      ],
    );
  }
}
