import 'dart:convert';

/// 从扫码结果中解析出的签到信息。
///
/// 雨课堂的签到二维码加密/编码格式并不固定（可能是 URL、JSON、或一串带校验的
/// token），因此该模型尽量保留原始内容，并给出最常见的解析字段，方便后续按平台
/// 实际格式调整。
class CheckinInfo {
  CheckinInfo({
    required this.raw,
    this.classId,
    this.checkinId,
    this.checkinCode,
    this.signInType,
    this.isEncrypted = true,
  });

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

  /// 是否为加密/动态 token（多数雨课堂扫码属于此类）。
  final bool isEncrypted;

  /// 是否解析出了可供上报的有效字段。
  /// 雨课堂扫码内容为一段 URL，故只要有原始内容即可上报；字段仅作展示。
  bool get isUsable => raw.trim().isNotEmpty;

  /// 从扫码字符串解析。依次尝试 JSON、URL 查询参数、纯 token 三种方式。
  static CheckinInfo parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return CheckinInfo(raw: text);
    }

    // 1) JSON 形式。
    final jsonMap = _tryParseJson(text);
    if (jsonMap != null) {
      return _fromMap(text, jsonMap);
    }

    // 2) URL 形式（提取查询参数）。
    final urlMap = _tryParseUrl(text);
    if (urlMap != null) {
      return _fromMap(text, urlMap);
    }

    // 3) 当作纯 token / 动态码。
    return CheckinInfo(
      raw: text,
      checkinCode: text,
      checkinId: text,
      isEncrypted: true,
    );
  }

  static Map<String, dynamic>? _tryParseJson(String text) {
    final start = text.indexOf('{');
    if (start < 0) {
      return null;
    }
    final end = text.lastIndexOf('}');
    if (end <= start) {
      return null;
    }
    try {
      final obj = jsonDecode(text.substring(start, end + 1));
      if (obj is Map<String, dynamic>) {
        return obj;
      }
    } catch (_) {
      // 非合法 JSON，继续。
    }
    return null;
  }

  static Map<String, dynamic>? _tryParseUrl(String text) {
    try {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.queryParameters.isEmpty) {
        return null;
      }
      return uri.queryParameters;
    } catch (_) {
      return null;
    }
  }

  static CheckinInfo _fromMap(String raw, Map<String, dynamic> map) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v != null && '$v'.isNotEmpty) {
          return '$v';
        }
      }
      return null;
    }

    final id = pick(['checkinId', 'checkin_id', 'signId', 'sign_id', 'id']);
    final code = pick(['checkinCode', 'checkin_code', 'code', 'secret']);
    final classId = pick(['classId', 'class_id', 'courseId', 'course_id']);
    final type = pick(['signInType', 'sign_in_type', 'type']);
    final isEncrypted = (map['encrypted'] == true) ||
        (map['isEncrypted'] == true) ||
        (id != null && code == null);

    return CheckinInfo(
      raw: raw,
      classId: classId,
      checkinId: id,
      checkinCode: code,
      signInType: type,
      isEncrypted: isEncrypted,
    );
  }

  @override
  String toString() => 'CheckinInfo(classId: $classId, checkinId: $checkinId)';
}
