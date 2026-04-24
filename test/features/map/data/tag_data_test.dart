import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/features/map/data/tag_repository.dart';

void main() {
  group('TagData', () {
    group('toJson', () {
      test('should serialize a server tag correctly', () {
        final tag = TagData(
          id: 'tag-1',
          userId: 'user-1',
          name: 'Work',
          color: 0xFFFF0000,
          createdAt: DateTime.utc(2024, 1, 15, 10, 30, 0),
          isLocal: false,
        );

        final json = tag.toJson();

        expect(json['id'], 'tag-1');
        expect(json['userId'], 'user-1');
        expect(json['name'], 'Work');
        expect(json['color'], 0xFFFF0000);
        expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
        expect(json['isLocal'], false);
      });

      test('should serialize a local tag correctly', () {
        final tag = TagData(
          id: 'local-tag-1',
          userId: null,
          name: 'Personal',
          color: 0xFF42A5F5,
          createdAt: DateTime.utc(2024, 2, 1, 8, 0, 0),
          isLocal: true,
        );

        final json = tag.toJson();

        expect(json['id'], 'local-tag-1');
        expect(json['userId'], null);
        expect(json['name'], 'Personal');
        expect(json['color'], 0xFF42A5F5);
        expect(json['createdAt'], '2024-02-01T08:00:00.000Z');
        expect(json['isLocal'], true);
      });
    });

    group('fromJson', () {
      test('should deserialize a server tag correctly', () {
        final json = {
          'id': 'tag-1',
          'userId': 'user-1',
          'name': 'Work',
          'color': 0xFFFF0000,
          'createdAt': '2024-01-15T10:30:00.000Z',
          'isLocal': false,
        };

        final tag = TagData.fromJson(json);

        expect(tag.id, 'tag-1');
        expect(tag.userId, 'user-1');
        expect(tag.name, 'Work');
        expect(tag.color, 0xFFFF0000);
        expect(tag.createdAt, DateTime.utc(2024, 1, 15, 10, 30, 0));
        expect(tag.isLocal, false);
      });

      test('should default isLocal to false when missing', () {
        final json = {
          'id': 'tag-1',
          'userId': 'user-1',
          'name': 'Work',
          'color': 0xFF00FF00,
          'createdAt': '2024-01-01T00:00:00.000Z',
        };

        final tag = TagData.fromJson(json);

        expect(tag.isLocal, false);
      });
    });

    group('local factory', () {
      test('should create a local tag with generated id and null userId', () {
        final tag = TagData.local(name: 'Test', color: 0xFF123456);

        expect(tag.id, isNotEmpty);
        expect(tag.userId, null);
        expect(tag.name, 'Test');
        expect(tag.color, 0xFF123456);
        expect(tag.isLocal, true);
      });

      test('should generate unique ids for separate calls', () {
        final a = TagData.local(name: 'A', color: 0xFFFFFFFF);
        final b = TagData.local(name: 'B', color: 0xFFFFFFFF);

        expect(a.id, isNot(b.id));
      });
    });

    group('copyWith', () {
      final base = TagData(
        id: 'tag-1',
        userId: 'user-1',
        name: 'Work',
        color: 0xFFFF0000,
        createdAt: DateTime.utc(2024, 1, 15),
        isLocal: false,
      );

      test('should update only specified fields', () {
        final updated = base.copyWith(name: 'Updated', color: 0xFF00FF00);

        expect(updated.id, base.id);
        expect(updated.userId, base.userId);
        expect(updated.name, 'Updated');
        expect(updated.color, 0xFF00FF00);
        expect(updated.createdAt, base.createdAt);
        expect(updated.isLocal, base.isLocal);
      });

      test('should preserve fields when no arguments', () {
        final copy = base.copyWith();

        expect(copy.id, base.id);
        expect(copy.userId, base.userId);
        expect(copy.name, base.name);
        expect(copy.color, base.color);
        expect(copy.createdAt, base.createdAt);
        expect(copy.isLocal, base.isLocal);
      });
    });

    group('round-trip serialization', () {
      test('should preserve all data', () {
        final original = TagData(
          id: 'tag-rt',
          userId: 'user-rt',
          name: 'Round-Trip',
          color: 0xFFABCDEF,
          createdAt: DateTime.utc(2024, 6, 15, 12, 0, 0),
          isLocal: false,
        );

        final restored = TagData.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.userId, original.userId);
        expect(restored.name, original.name);
        expect(restored.color, original.color);
        expect(restored.createdAt, original.createdAt);
        expect(restored.isLocal, original.isLocal);
      });
    });
  });

  group('colorIntToHex', () {
    test('should convert red to #FF0000', () {
      expect(colorIntToHex(0xFFFF0000), '#FF0000');
    });

    test('should convert blue-ish to #42A5F5', () {
      expect(colorIntToHex(0xFF42A5F5), '#42A5F5');
    });

    test('should pad with zeros', () {
      expect(colorIntToHex(0xFF010203), '#010203');
    });

    test('should uppercase output', () {
      expect(colorIntToHex(0xFFabcdef), '#ABCDEF');
    });
  });

  group('hexToColorInt', () {
    test('should parse #FF0000 to ARGB with full alpha', () {
      expect(hexToColorInt('#FF0000'), 0xFFFF0000);
    });

    test('should accept hex without leading #', () {
      expect(hexToColorInt('42A5F5'), 0xFF42A5F5);
    });

    test('should parse lowercase hex', () {
      expect(hexToColorInt('#abcdef'), 0xFFABCDEF);
    });
  });

  group('color conversion round-trip', () {
    test('should round-trip for several colors with full alpha', () {
      final samples = [
        0xFFFF0000,
        0xFF00FF00,
        0xFF0000FF,
        0xFF42A5F5,
        0xFFABCDEF,
        0xFF000000,
        0xFFFFFFFF,
      ];
      for (final x in samples) {
        expect(hexToColorInt(colorIntToHex(x)), x);
      }
    });
  });
}
