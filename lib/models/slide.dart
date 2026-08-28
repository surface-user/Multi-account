/// 课件中的一页幻灯片。
class Slide {
  Slide({
    required this.index,
    this.title,
    this.imageUrl,
    this.pageUrl,
    this.resourceId,
  });

  /// 页码（从 0 开始，用于排序与显示）。
  final int index;

  /// 页面标题。
  final String? title;

  /// 幻灯片图片地址（可直接用 image 组件展示的静态图）。
  final String? imageUrl;

  /// 页面地址（用于 WebView 兜底展示动态/交互课件）。
  final String? pageUrl;

  /// 资源 ID。
  final String? resourceId;

  /// 是否可展示：只要有图片或页面地址任一即可。
  bool get isRenderable => imageUrl != null || pageUrl != null;

  factory Slide.fromJson(Map<String, dynamic> json, int index) {
    return Slide(
      index: index,
      title: json['title'] as String?,
      imageUrl: json['image'] ?? json['image_url'] as String?,
      pageUrl: json['page_url'] ?? json['url'] as String?,
      resourceId: json['resource_id'] != null
          ? '${json['resource_id']}'
          : null,
    );
  }

  @override
  String toString() => 'Slide($index, $title)';
}
