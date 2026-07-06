# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter application. Main Dart code lives in `lib/`, with the entry point in `lib/main.dart`. App-level
routing, pages, bindings, controllers, models, and database code are organized under `lib/app/`. Tests live in `test/`,
starting with `test/widget_test.dart`. Android platform files are under `android/`; avoid editing generated files unless
platform integration requires it. Generated Dart files such as `*.g.dart` should be updated through the appropriate
generator rather than manual edits.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies from `pubspec.yaml`.
- `flutter analyze`: run static analysis using `analysis_options.yaml`.
- `flutter test`: run the project test suite.
- `flutter run`: launch the app on a connected device or emulator.
- `flutter build apk`: create an Android APK when a release artifact is required.
- `dart run build_runner build --delete-conflicting-outputs`: regenerate database/model code when annotations change.

## Coding Style & Naming Conventions

Follow official Dart style with two-space indentation and trailing commas for readable widget trees. Use `PascalCase`
for classes and widgets, `camelCase` for variables, methods, and fields, and `snake_case.dart` for file names. Keep
controllers, bindings, views, models, routes, and database tables in their existing feature-oriented folders. Prefer
small, reusable widgets and services over large methods with mixed responsibilities.

## Testing Guidelines

Use Flutter’s built-in `flutter_test` framework. Place tests in `test/` and name files with the `_test.dart` suffix. Add
widget tests for UI behavior and unit tests for model, routing, and database logic when behavior changes. Run
`flutter test` before submitting changes; run `flutter analyze` when touching app architecture or generated-code inputs.

## Development Practices

- After modifying Flutter/Dart source code, if a Flutter debug session is already running and supports hot reload,
  automatically run hot reload before the final handoff.
- After changes, run at least one relevant validation command such as `flutter analyze`, `flutter test`, or a build
  command before submitting work.

## Commit & Pull Request Guidelines

This checkout does not include Git history, so use Conventional Commits for consistency, for example
`feat(home): 添加图片选择入口` or `fix(database): 修复时间转换`. Pull requests should include a short summary,
validation commands run, related issue links, and screenshots or recordings for visible UI changes.
After completing any future feature extension or bug fix, run the relevant validation command and create a Git commit
automatically with a concise Chinese Conventional Commit message.

## Security & Configuration Tips

Do not commit secrets, signing keys, or local machine paths. Keep environment-specific Android values in local
configuration files where possible. Do not modify ignored build outputs such as `.dart_tool/`, `build/`, or
`pubspec.lock` unless the project policy explicitly changes.
