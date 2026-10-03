import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:talker/talker.dart';

import '../../extensions/talker_data_extension.dart';

/// A Hive [TypeAdapter] that persists [TalkerData] entries as JSON.
///
/// The payload is produced by [TalkerDataExtension.toJson] and therefore
/// includes the message, title, level, key, timestamp, stack trace and any
/// attached error / exception. Stack traces are serialised with the
/// `stack_trace` package and parsed back into a [Trace] on read.
class TalkerDataAdapter extends TypeAdapter<TalkerData> {
  /// The Hive type id reserved for [TalkerData].
  ///
  /// `package:hive` only accepts external type ids in the range `0..223`
  /// (`hive_ce` allowed larger values, so this is the one incompatibility to
  /// keep in mind while the two packages are swapped).
  static const int typeIdValue = 223;

  @override
  final int typeId = typeIdValue;

  @override
  TalkerData read(BinaryReader reader) {
    final raw = reader.read();
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is Map) {
      return talkerDataFromJson(decoded.cast<String, dynamic>());
    }
    throw HiveError('Unexpected TalkerData payload: $decoded');
  }

  @override
  void write(BinaryWriter writer, TalkerData obj) {
    writer.write(jsonEncode(obj.toJson()));
  }
}
