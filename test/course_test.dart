import 'package:flutter_test/flutter_test.dart';
import 'package:rain_classroom_helper/models/course.dart';

void main() {
  group('Course.fromJson', () {
    test('兼容常见字段', () {
      final course = Course.fromJson({
        'id': 42,
        'name': '高等数学',
        'teacher_name': '张老师',
      });
      expect(course.id, '42');
      expect(course.name, '高等数学');
      expect(course.teacherName, '张老师');
    });

    test('兼容 class_id / course_name 变体', () {
      final course = Course.fromJson({
        'class_id': 'abc',
        'course_name': '大学物理',
      });
      expect(course.id, 'abc');
      expect(course.classId, 'abc');
      expect(course.name, '大学物理');
    });

    test('空对象解析', () {
      final course = Course.fromJson({});
      expect(course.id, '');
      expect(course.name, '');
    });
  });
}
