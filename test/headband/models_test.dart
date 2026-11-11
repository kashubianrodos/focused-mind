import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/models.dart';

void main() {
  group('contactQualityFromOhms', () {
    test('below 500 kΩ is good', () {
      expect(contactQualityFromOhms(0), ContactQuality.good);
      expect(contactQualityFromOhms(499e3), ContactQuality.good);
    });

    test('500 kΩ up to 2 MΩ is fair', () {
      expect(contactQualityFromOhms(500e3), ContactQuality.fair);
      expect(contactQualityFromOhms(1.99e6), ContactQuality.fair);
    });

    test('2 MΩ and above, infinity, NaN and negatives are poor', () {
      expect(contactQualityFromOhms(2e6), ContactQuality.poor);
      expect(contactQualityFromOhms(double.infinity), ContactQuality.poor);
      expect(contactQualityFromOhms(double.nan), ContactQuality.poor);
      expect(contactQualityFromOhms(-1), ContactQuality.poor);
    });
  });

  group('ContactReport', () {
    test('calibration gate needs every electrode at least fair', () {
      final ok = ContactReport.fromOhms(
        o1: 100e3,
        o2: 1e6,
        t3: 200e3,
        t4: 300e3,
      );
      expect(ok.allAtLeastFair, isTrue);
      expect(ok.poorElectrodes, isEmpty);

      final bad = ContactReport.fromOhms(
        o1: 100e3,
        o2: double.infinity,
        t3: 200e3,
        t4: 300e3,
      );
      expect(bad.allAtLeastFair, isFalse);
      expect(bad.poorElectrodes, [Electrode.o2]);
    });
  });

  group('DeviceInfo', () {
    test('round-trips through JSON', () {
      const d = DeviceInfo(
        name: 'Mindo',
        serialNumber: '123',
        address: 'AA:BB',
        family: HeadbandFamily.headband,
        model: 4,
      );
      expect(DeviceInfo.fromJson(d.toJson()), d);
    });

    test('unknown family is rejected', () {
      expect(DeviceInfo.fromJson({'family': 'toaster'}), isNull);
    });
  });
}
