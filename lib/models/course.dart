/// 课程模型。
class Course {
  Course({
    required this.id,
    required this.name,
    this.teacherName,
    this.classId,
    this.presentationId,
    this.coverUrl,
    this.term,
  });

  /// 课程/班级 ID。
  final String id;

  /// 课程名称。
  final String name;

  /// 教师名称。
  final String? teacherName;

  /// 班级 ID（用于拉取课件）。
  final String? classId;

  /// 课件（presentation）ID，拉取 PPT 用。
  final String? presentationId;

  /// 封面图。
  final String? coverUrl;

  /// 学期。
  final String? term;

  factory Course.fromJson(Map<String, dynamic> json) {
    // 兼容雨课堂返回结构:
    //  { course_id, course_name, classroom_id, lesson_id, presentation_id,
    //    teacher: { name, avatar }, term/term_name }
    final teacher = json['teacher'];
    String? teacherName;
    if (teacher is Map) {
      teacherName = teacher['name']?.toString();
    } else if (teacher is String) {
      teacherName = teacher;
    } else {
      teacherName = json['teacher_name']?.toString();
    }

    final id = '${json['course_id'] ?? json['id'] ?? json['class_id'] ?? ''}';
    return Course(
      id: id,
      name: json['course_name']?.toString() ??
          json['name']?.toString() ??
          json['title']?.toString() ??
          '',
      teacherName: teacherName,
      classId: (json['class_id'] ?? json['classroom_id'] ?? json['lesson_id']
              ?? id)
          .toString(),
      presentationId: (json['presentation_id'] ?? json['lesson_id'])
          ?.toString(),
      coverUrl: json['cover']?.toString() ?? json['cover_url']?.toString(),
      term: json['term']?.toString() ?? json['term_name']?.toString(),
    );
  }

  @override
  String toString() => 'Course($name)';
}
