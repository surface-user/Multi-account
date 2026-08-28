/// 字符串工具。
class StringUtils {
  StringUtils._();

  /// 取名字的首字符（用于头像占位）。空串返回 '?'。
  /// 避免引入 characters 依赖，足够用于中文/英文展示。
  static String initialOf(String name) {
    final text = name.trim();
    if (text.isEmpty) {
      return '?';
    }
    return text.substring(0, 1).toUpperCase();
  }
}
