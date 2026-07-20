import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';

/// Integration tests for P5 checksum skip + dirty-row protection in
/// [LocalDeliveryDao.insertAllFromApiItems].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.debugResetForTests();
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.debugResetForTests();
    AppDatabase.debugDatabasePath = null;
  });

  Map<String, dynamic> apiItem({
    required String barcode,
    required String status,
    required String checksum,
    String? name,
  }) {
    return {
      'barcode': barcode,
      'delivery_status': status,
      'recipient_name': name ?? 'Courier $barcode',
      'data_checksum': checksum,
    };
  }

  Future<Map<String, Object?>?> row(String barcode) async {
    final db = await AppDatabase.getInstance();
    final rows = await db.query(
      'local_deliveries',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    return rows.isEmpty ? null : rows.first;
  }

  test('P5: matching checksum skips rewrite of clean row', () async {
    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(barcode: 'B1', status: 'FOR_DELIVERY', checksum: 'hash-1'),
    ], serverStatus: 'FOR_DELIVERY');

    final first = await row('B1');
    expect(first, isNotNull);
    final firstUpdated = first!['updated_at'] as int;
    final firstName = first['recipient_name'];

    // Same checksum, different name would normally replace — must skip.
    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(
        barcode: 'B1',
        status: 'FOR_DELIVERY',
        checksum: 'hash-1',
        name: 'CHANGED NAME SHOULD NOT APPLY',
      ),
    ], serverStatus: 'FOR_DELIVERY');

    final second = await row('B1');
    expect(second!['recipient_name'], firstName);
    expect(second['updated_at'], firstUpdated);
    expect(second['data_checksum'], 'hash-1');
  });

  test('P5: different checksum updates clean row', () async {
    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(barcode: 'B2', status: 'FOR_DELIVERY', checksum: 'v1'),
    ], serverStatus: 'FOR_DELIVERY');

    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(
        barcode: 'B2',
        status: 'FOR_DELIVERY',
        checksum: 'v2',
        name: 'Updated Recipient',
      ),
    ], serverStatus: 'FOR_DELIVERY');

    final r = await row('B2');
    expect(r!['recipient_name'], 'Updated Recipient');
    expect(r['data_checksum'], 'v2');
  });

  test('accuracy: dirty row status not overwritten by matching checksum path',
      () async {
    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(barcode: 'B3', status: 'FOR_DELIVERY', checksum: 'same'),
    ], serverStatus: 'FOR_DELIVERY');

    final db = await AppDatabase.getInstance();
    await db.update(
      'local_deliveries',
      {
        'sync_status': 'dirty',
        'delivery_status': 'DELIVERED',
        'recipient_name': 'Courier Local POD',
      },
      where: 'barcode = ?',
      whereArgs: ['B3'],
    );

    // Server still says pending with same checksum — dirty status must win.
    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(
        barcode: 'B3',
        status: 'FOR_DELIVERY',
        checksum: 'same',
        name: 'Server Pending Name',
      ),
    ], serverStatus: 'FOR_DELIVERY');

    final r = await row('B3');
    expect(r!['sync_status'], 'dirty');
    expect(r['delivery_status'], 'DELIVERED');
    expect(r['recipient_name'], 'Courier Local POD');
  });

  test('new barcode is inserted when no local row exists', () async {
    await LocalDeliveryDao.instance.insertAllFromApiItems([
      apiItem(barcode: 'B4', status: 'FOR_DELIVERY', checksum: 'new'),
    ], serverStatus: 'FOR_DELIVERY');

    final r = await row('B4');
    expect(r, isNotNull);
    expect(r!['barcode'], 'B4');
    expect(jsonDecode(r['raw_json'] as String)['data_checksum'], 'new');
  });
}
