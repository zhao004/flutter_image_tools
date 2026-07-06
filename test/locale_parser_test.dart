import 'package:flutter/widgets.dart';
import 'package:flutter_image_tools/app/theme/locale_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('locale_parser', () {
    test('显式语言设置映射到已注册翻译 Locale', () {
      // 覆盖设置页保存的稳定字符串，确保不会传出翻译表未注册的 Locale。
      expect(localeFromSetting('zh_cn'), const Locale('zh', 'CN'));
      expect(localeFromSetting('zh_tw'), const Locale('zh', 'TW'));
      expect(localeFromSetting('en'), const Locale('en'));
      expect(localeFromSetting('system'), isNull);
    });

    test('系统语言归一化到支持的翻译 Locale', () {
      // 覆盖首次安装最常见的系统 Locale 变体，避免界面显示 home.xxx 字段名。
      expect(resolveSupportedLocale(const Locale('zh')), defaultAppLocale);
      expect(
        resolveSupportedLocale(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'CN',
          ),
        ),
        defaultAppLocale,
      );
      expect(
        resolveSupportedLocale(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'HK',
          ),
        ),
        const Locale('zh', 'TW'),
      );
      expect(
        resolveSupportedLocale(const Locale('en', 'US')),
        const Locale('en'),
      );
      expect(
        resolveSupportedLocale(const Locale('ja', 'JP')),
        defaultAppLocale,
      );
    });

    test('跟随系统设置会返回最终可用语言', () {
      // 历史脏值和 system 都按设备语言处理，再回退到应用默认语言。
      expect(
        localeFromSettingOrDevice('system', const Locale('en', 'GB')),
        const Locale('en'),
      );
      expect(
        localeFromSettingOrDevice('unknown', const Locale('ko', 'KR')),
        defaultAppLocale,
      );
    });
  });
}
