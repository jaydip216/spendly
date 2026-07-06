import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  String name = '';

  /// Material color value used for chips and chart slices.
  int colorValue = 0xFF9E9E9E;

  /// Seeded defaults cannot be renamed or deleted.
  bool isDefault = false;
}
