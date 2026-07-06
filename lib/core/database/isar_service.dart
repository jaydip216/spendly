import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/category.dart';
import '../models/expense.dart';

Future<Isar> openSpendlyIsar() async {
  if (Isar.instanceNames.isNotEmpty) {
    return Future.value(Isar.getInstance(Isar.instanceNames.first));
  }

  final Directory dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [ExpenseSchema, CategorySchema],
    directory: dir.path,
    name: 'spendly',
  );
}
