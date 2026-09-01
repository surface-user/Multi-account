/// 从扫码结果中解析出的签到信息。
///
/// 依据 course_helper：雨课堂签到二维码内容是一个 URL，其 baseUrl 必须包含
/// [rainCheckinUrlPattern] 才视为可上报的签到码；其它内容（微信跳转链、纯 token、
/// JSON 等）一律视为不可用，避免把错误的二维码内容当成签到码上报。
class CheckinInfo {
  CheckinInfo({
    required this.raw,
    this.classId,
    this.checkinId,
    this.checkinCode,
    this.signInType,
    this.isEncrypted = true,
    this.isValidRainCheckin = false,
  });

  /// 雨课堂签到二维码 URL 的特征路径（与 course_helper 一致）。
  static const String rainCheckinUrlPattern =
      '.yuketang.cn/api/v3/lesson/check-in/dynamic-qr-code';

  /// 扫码得到的原始字符串。
  final String raw;

  /// 课程/班级 ID。
  final String? classId;

  /// 签到 ID。
  final String? checkinId;

  /// 签到码（动态码 / token）。
  final String? checkinCode;

  /// 签到类型枚举值（如正常签到/签退）。
  final String? signInType;

  /// 是否为加密/动态 token。
  final bool isEncrypted;

  /// 是否被识别为雨课堂签到二维码（URL 的 baseUrl 匹配 [rainCheckinUrlPattern]）。
  /// 只有为 true 才允许上报签到。
  final bool isValidRainCheckin;

  /// 是否可上报签到（是雨课堂签到二维码）。
  bool get isUsable => isValidRainCheckin;

  /// 从扫码字符串解析。仅 URL 且 baseUrl 匹配雨课堂签到特征路径才视为可用。
  static CheckinInfo parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return CheckinInfo(raw: text);
    }

    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      // 非 URL（纯 token / JSON 等）：雨课堂签到必须是上式 URL，视为不可用。
      return CheckinInfo(raw: text);
    }

    final baseUrl = uri.origin + uri.path;
    final isValid = baseUrl.contains(rainCheckinUrlPattern);
    if (!isValid) {
      // 非雨课堂签到二维码：不提取字段、不可用（避免把别的二维码误标成签到码）。
      return CheckinInfo(raw: text, isEncrypted: true);
    }

    final params = uri.queryParameters;
    return CheckinInfo(
      raw: text,
      classId: _pick(
          params, ['classId', 'class_id', 'courseId', 'course_id', 'classroom_id']),
      checkinId: _pick(params,
          ['checkinId', 'checkin_id', 'signId', 'sign_id', 'id', 'lessonId', 'lesson_id']),
      checkinCode:
          _pick(params, ['checkinCode', 'checkin_code', 'code', 'secret']),
      signInType: _pick(params, ['signInType', 'sign_in_type', 'type']),
      isEncrypted: true,
      isValidRainCheckin: true,
    );
  }

  static String? _pick(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v != null && v.isNotEmpty) {
        return v;
      }
    }
    return null;
  }

  @override
  String toString() => 'CheckinInfo(classId: $classId, checkinId: $checkinId)';
}
