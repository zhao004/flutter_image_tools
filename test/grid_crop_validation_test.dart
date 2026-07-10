import 'package:flutter_image_tools/app/services/local_image_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('九宫格裁剪比例校验', () {
    test('竖图默认 78% 范围不会被混合归一化基准误判', () {
      expect(
        LocalImageChannel.isValidGridCropRatio(
          left: 0.11,
          top: 0.3245,
          size: 0.78,
        ),
        isTrue,
      );
    });

    test('拒绝越界、非有限值和空尺寸', () {
      expect(
        LocalImageChannel.isValidGridCropRatio(left: -0.01, top: 0, size: 0.5),
        isFalse,
      );
      expect(
        LocalImageChannel.isValidGridCropRatio(
          left: 0,
          top: double.nan,
          size: 0.5,
        ),
        isFalse,
      );
      expect(
        LocalImageChannel.isValidGridCropRatio(left: 0, top: 0, size: 0),
        isFalse,
      );
    });
  });
}
