import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 메모 서식 편집기(flutter_quill) 문구.
/// 필리핀어처럼 편집기가 번역을 갖고 있지 않은 언어는 영어로 대신 표시합니다.
class QuillFallbackLocalizationsDelegate
    extends LocalizationsDelegate<FlutterQuillLocalizations> {
  const QuillFallbackLocalizationsDelegate();

  static const _inner = FlutterQuillLocalizations.delegate;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FlutterQuillLocalizations> load(Locale locale) => _inner.load(
      _inner.isSupported(locale) ? locale : const Locale('en'));

  @override
  bool shouldReload(QuillFallbackLocalizationsDelegate old) => false;
}
