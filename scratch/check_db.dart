import 'package:drift/native.dart';
import 'package:isai/core/database/database.dart';
import 'dart:io';

void main() async {
  // Database file is located at App Data Directory under databases/isai.db or similar.
  // Let's find it.
  final dbPath = '/home/abinanthan/.local/share/isai/isai.db'; // standard path, let's check
  // Actually drift database open helper knows where it is, let's check database.dart or just print
  print('Checking database...');
}
