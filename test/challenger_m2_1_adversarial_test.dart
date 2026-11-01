import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/features/progress/components/howbody_link_sheet.dart';
import 'package:incline_app/features/progress/components/howbody_qr_scanner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial QR Payload Tests — Malformed URLs & Query Syntax', () {
    test('Handles unparseable URI strings without throwing', () {
      final unparseable = [
        '://inclinegym.com/scan-login',
        'http://',
        'https://',
        'https://:8080/scan-login',
        'https://inclinegym.com:not_a_port/scan-login',
        'https://[::invalid_ipv6]/scan-login',
        'http:///scan-login?equipmentNo=1&scanId=2',
        '   https://   ',
      ];

      for (final raw in unparseable) {
        expect(
          () => HowbodyQrPayload.parse(raw),
          returnsNormally,
          reason: 'Failed to handle unparseable URI gracefully: "$raw"',
        );
      }
    });

    test('Handles invalid URI syntax percent-encodings rejected by Uri.tryParse', () {
      final badPercentEncodings = [
        'https://inclinegym.com/scan-login?equipmentNo=INC%ZZ&scanId=100',
        'https://inclinegym.com/scan-login?equipmentNo=INC01&scanId=100%',
        'https://inclinegym.com/scan-login?%ZZ=equipmentNo&scanId=100',
        'https://inclinegym.com/scan-login?equipmentNo=%2&scanId=100',
        'equipmentNo=INC%ZZ&scanId=100',
        'equipmentNo=INC01&scanId=%',
      ];

      for (final raw in badPercentEncodings) {
        expect(
          () => HowbodyQrPayload.parse(raw),
          returnsNormally,
          reason: 'Crashed on invalid percent encoding: "$raw"',
        );
      }
    });

    test('BUG FINDING: Truncated multi-byte UTF-8 percent-encoding in URI query causes uncaught FormatException', () {
      // In Dart, Uri.tryParse accepts strings with valid hex percent pairs (like %E0%A4%A or %F0%9F%98),
      // but accessing uri.queryParameters triggers utf8.decode, which throws FormatException: Missing extension byte.
      // Because line 29-30 of howbody_qr_scanner_sheet.dart has no try/catch around uri.queryParameters,
      // this unhandled exception crashes the QR parser.
      const raw = 'https://inclinegym.com/scan-login?equipmentNo=INC01&scanId=%E0%A4%A';
      expect(
        () => HowbodyQrPayload.parse(raw),
        returnsNormally,
        reason: 'HowbodyQrPayload.parse must catch FormatException from uri.queryParameters',
      );
    });

    test('BUG FINDING: Whitespace-only parameters (percent-encoded or JSON) are accepted instead of rejected as null', () {
      // eq.isNotEmpty check returns true for '   ', allowing blank identifiers into HowbodyLinkSheet
      const encodedUrl = 'https://inclinegym.com/scan-login?equipmentNo=%20%20%20&scanId=%20%20%20';
      final urlPayload = HowbodyQrPayload.parse(encodedUrl);
      expect(
        urlPayload,
        isNull,
        reason: 'Percent-encoded whitespace equipmentNo and scanId should be rejected cleanly as null',
      );

      const jsonRaw = '{"equipmentNo":"   ","scanId":"   "}';
      final jsonPayload = HowbodyQrPayload.parse(jsonRaw);
      expect(
        jsonPayload,
        isNull,
        reason: 'JSON whitespace equipmentNo and scanId should be rejected cleanly as null',
      );
    });

    test('Handles truncated paths and empty query parameters', () {
      final truncated = [
        'https://inclinegym.com',
        'https://inclinegym.com/',
        'https://inclinegym.com/scan',
        'https://inclinegym.com/scan-login',
        'https://inclinegym.com/scan-login?',
        'https://inclinegym.com/howbody-login?',
        'https://inclinegym.com/scan-login?foo=bar',
        'https://inclinegym.com/scan-login?equipmentNo=&scanId=',
        '?===&&&',
        '???',
        '&&&',
        '=',
      ];

      for (final raw in truncated) {
        final payload = HowbodyQrPayload.parse(raw);
        expect(payload, isNull, reason: 'Expected null for truncated/empty query: "$raw"');
      }
    });
  });

  group('Adversarial QR Payload Tests — Extra & Missing Query Parameters', () {
    test('Rejects when equipmentNo is missing', () {
      const url = 'https://inclinegym.com/scan-login?scanId=sess_999&kind=body';
      expect(HowbodyQrPayload.parse(url), isNull);
    });

    test('Rejects when scanId is missing', () {
      const url = 'https://inclinegym.com/scan-login?equipmentNo=INC-999&kind=body';
      expect(HowbodyQrPayload.parse(url), isNull);
    });

    test('Defaults kind to "body" when kind parameter is missing', () {
      const url = 'https://inclinegym.com/scan-login?equipmentNo=INC-999&scanId=sess_999';
      final payload = HowbodyQrPayload.parse(url);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-999'));
      expect(payload.scanId, equals('sess_999'));
      expect(payload.kind, equals('body'));
    });

    test('Normalizes case-insensitive kinds and falls back safely on unknown kinds', () {
      final kinds = {
        'POSTURE': 'posture',
        'Posture': 'posture',
        'posture': 'posture',
        'BODY': 'body',
        'Body': 'body',
        'body': 'body',
        'UNKNOWN_KIND': 'body',
        '12345': 'body',
        '': 'body',
      };

      for (final entry in kinds.entries) {
        final url =
            'https://inclinegym.com/scan-login?equipmentNo=INC-01&scanId=S1&kind=${entry.key}';
        final payload = HowbodyQrPayload.parse(url);
        expect(payload, isNotNull);
        expect(
          payload!.kind,
          equals(entry.value),
          reason: 'Failed for kind input "${entry.key}"',
        );
      }
    });

    test('Handles extra benign and malicious query parameters', () {
      const url =
          'https://inclinegym.com/scan-login?extra1=attack&equipmentNo=INC-OK-01&token=evil_token&scanId=SESS_OK_01&kind=posture&debug=true&role=admin';
      final payload = HowbodyQrPayload.parse(url);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-OK-01'));
      expect(payload.scanId, equals('SESS_OK_01'));
      expect(payload.kind, equals('posture'));
    });

    test('Supports alternative query parameter aliases: device, session, scanType', () {
      const url = 'https://inclinegym.com/scan-login?device=INC-DEV-01&session=SESS-DEV-01&scanType=posture';
      final payload = HowbodyQrPayload.parse(url);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-DEV-01'));
      expect(payload.scanId, equals('SESS-DEV-01'));
      expect(payload.kind, equals('posture'));
    });
  });

  group('Adversarial QR Payload Tests — Injection Payloads & Unicode Stress', () {
    test('Handles SQL injection strings in parameters safely', () {
      const sqlEq = "INC-01' OR '1'='1; DROP TABLE howbody_devices; --";
      const sqlSid = "sess' UNION SELECT * FROM members; --";
      final raw = 'equipmentNo=${Uri.encodeQueryComponent(sqlEq)}&scanId=${Uri.encodeQueryComponent(sqlSid)}&kind=body';

      final payload = HowbodyQrPayload.parse(raw);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals(sqlEq));
      expect(payload.scanId, equals(sqlSid));
    });

    test('Handles HTML / Script injection tags safely without execution or crash', () {
      const xssEq = '<script>alert("XSS")</script>';
      const xssSid = '<img src=x onerror=alert(1)>';
      final raw = 'https://inclinegym.com/scan-login?equipmentNo=${Uri.encodeQueryComponent(xssEq)}&scanId=${Uri.encodeQueryComponent(xssSid)}';

      final payload = HowbodyQrPayload.parse(raw);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals(xssEq));
      expect(payload.scanId, equals(xssSid));
    });

    test('Handles ultra-long parameter strings (>10KB) without OOM or stack overflow', () {
      final longEq = 'EQ_${'A' * 12000}';
      final longSid = 'SID_${'B' * 12000}';
      final raw = 'https://inclinegym.com/scan-login?equipmentNo=$longEq&scanId=$longSid';

      final payload = HowbodyQrPayload.parse(raw);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo.length, equals(longEq.length));
      expect(payload.scanId.length, equals(longSid.length));
    });

    test('Handles non-ASCII, UTF-8 Multibyte, and Emoji in identifiers', () {
      const emojiEq = '🏋️‍♂️_INC_체성분_분석기_01';
      const emojiSid = 'セッション_✨_№108_مرحبا';
      final raw = 'https://inclinegym.com/scan-login?equipmentNo=${Uri.encodeQueryComponent(emojiEq)}&scanId=${Uri.encodeQueryComponent(emojiSid)}&kind=posture';

      final payload = HowbodyQrPayload.parse(raw);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals(emojiEq));
      expect(payload.scanId, equals(emojiSid));
      expect(payload.kind, equals('posture'));
    });
  });

  group('Adversarial QR Payload Tests — Raw JSON Payloads', () {
    test('Parses valid camelCase JSON payload', () {
      const jsonStr = '{"equipmentNo":"INC-JSON-01","scanId":"SESS-01","kind":"body"}';
      final payload = HowbodyQrPayload.parse(jsonStr);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-JSON-01'));
      expect(payload.scanId, equals('SESS-01'));
      expect(payload.kind, equals('body'));
    });

    test('Parses valid snake_case JSON payload', () {
      const jsonStr = '{"equipment_no":"INC-JSON-02","scan_id":"SESS-02","scanType":"posture"}';
      final payload = HowbodyQrPayload.parse(jsonStr);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-JSON-02'));
      expect(payload.scanId, equals('SESS-02'));
      expect(payload.kind, equals('posture'));
    });

    test('Handles truncated, malformed, or incomplete JSON strings gracefully', () {
      final badJsons = [
        '{"equipmentNo":"INC-01","scanId":',
        '{"equipmentNo":',
        '{',
        '{"equipmentNo":"INC-01"}', // missing scanId
        '{"scanId":"SESS-01"}', // missing equipmentNo
        '{"equipmentNo":"","scanId":""}', // empty
        '{"equipmentNo":null,"scanId":null}', // null values
        '{"equipmentNo":null,"scanId":"SESS-01"}',
        '[{"equipmentNo":"INC-01","scanId":"SESS-01"}]', // Array, not Map
        '"just_a_string"',
        '123456',
        'true',
        'null',
      ];

      for (final bad in badJsons) {
        expect(
          () => HowbodyQrPayload.parse(bad),
          returnsNormally,
          reason: 'Threw uncaught exception on bad JSON: "$bad"',
        );
        final payload = HowbodyQrPayload.parse(bad);
        expect(payload, isNull, reason: 'Expected null for invalid JSON: "$bad"');
      }
    });

    test('Handles numeric and boolean JSON types cleanly via toString()', () {
      const jsonWithNumbers = '{"equipmentNo":99001,"scanId":88002,"kind":"body"}';
      final payload = HowbodyQrPayload.parse(jsonWithNumbers);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('99001'));
      expect(payload.scanId, equals('88002'));
    });

    test('Handles unexpected nested fields and large JSON objects', () {
      final bigMap = {
        'equipmentNo': 'INC-NESTED-01',
        'scanId': 'SESS-NESTED-01',
        'kind': 'posture',
        'metadata': {'gym': 'UDR', 'coords': [28.6139, 77.2090]},
        'nestedPayload': List.generate(500, (i) => 'item_$i'),
        '__proto__': {'polluted': true},
      };
      final jsonStr = jsonEncode(bigMap);

      final payload = HowbodyQrPayload.parse(jsonStr);
      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-NESTED-01'));
      expect(payload.scanId, equals('SESS-NESTED-01'));
      expect(payload.kind, equals('posture'));
    });
  });

  group('Adversarial QR Payload Tests — Custom Schemes & Case Sensitivity', () {
    test('Parses standard custom scheme incline://', () {
      const uri = 'incline://howbody?equipmentNo=INC-SCHEME-01&scanId=SESS-SCHEME-01&kind=posture';
      final payload = HowbodyQrPayload.parse(uri);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-SCHEME-01'));
      expect(payload.scanId, equals('SESS-SCHEME-01'));
      expect(payload.kind, equals('posture'));
    });

    test('Parses uppercase custom scheme INCLINE://...', () {
      const uri = 'INCLINE://HOWBODY?equipmentNo=INC-SCHEME-02&scanId=SESS-SCHEME-02&kind=body';
      final payload = HowbodyQrPayload.parse(uri);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-SCHEME-02'));
      expect(payload.scanId, equals('SESS-SCHEME-02'));
      expect(payload.kind, equals('body'));
    });

    test('Parses arbitrary or custom vendor schemes howbody://...', () {
      const uri = 'howbody://pairing?equipmentNo=INC-VENDOR-01&scanId=SESS-VENDOR-01';
      final payload = HowbodyQrPayload.parse(uri);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-VENDOR-01'));
      expect(payload.scanId, equals('SESS-VENDOR-01'));
      expect(payload.kind, equals('body'));
    });

    test('Parses custom scheme without double slash incline:scan-login?...', () {
      const uri = 'incline:scan-login?equipmentNo=INC-OPAQUE-01&scanId=SESS-OPAQUE-01';
      final payload = HowbodyQrPayload.parse(uri);

      expect(payload, isNotNull);
      expect(payload!.equipmentNo, equals('INC-OPAQUE-01'));
      expect(payload.scanId, equals('SESS-OPAQUE-01'));
      expect(payload.kind, equals('body'));
    });
  });

  group('Adversarial HowbodyHeightConverter Tests — Boundaries & Out of Bounds', () {
    test('Exact boundary validation at minValidCm (100.0) and maxValidCm (250.0)', () {
      // Exactly at min boundary
      expect(HowbodyHeightConverter.isValidHeightCm(100.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(99.999999), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(99.9), isFalse);

      // Exactly at max boundary
      expect(HowbodyHeightConverter.isValidHeightCm(250.0), isTrue);
      expect(HowbodyHeightConverter.isValidHeightCm(250.000001), isFalse);
      expect(HowbodyHeightConverter.isValidHeightCm(250.1), isFalse);

      // Mid-range sanity check
      expect(HowbodyHeightConverter.isValidHeightCm(175.0), isTrue);
    });

    test('Rejects out-of-bounds, negative, zero, and extreme values', () {
      final invalidHeights = [
        0.0,
        -0.001,
        -150.0,
        -250.0,
        -99999.0,
        50.0,
        99.0,
        250.5,
        300.0,
        500.0,
        1000.0,
        1e6,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final h in invalidHeights) {
        expect(
          HowbodyHeightConverter.isValidHeightCm(h),
          isFalse,
          reason: 'Expected $h to be invalid height',
        );
      }
    });
  });

  group('Adversarial HowbodyHeightConverter Tests — Invariants & Roundtrip Stability', () {
    test('INVARIANT: inches must never exceed 11 across all dense cm inputs [100.0..250.0]', () {
      // Test every 0.1 cm increment across the entire valid domain (1501 test points)
      for (double cm = 100.0; cm <= 250.05; cm += 0.1) {
        final result = HowbodyHeightConverter.cmToFeetInches(cm);

        expect(
          result.inches >= 0 && result.inches <= 11,
          isTrue,
          reason: 'Inches invariant violated: $cm cm yielded ${result.feet}ft ${result.inches}in',
        );
        expect(
          result.feet >= 3 && result.feet <= 8,
          isTrue,
          reason: 'Feet out of human range: $cm cm yielded ${result.feet}ft ${result.inches}in',
        );
      }
    });

    test('Rollover test: values where inches round to 12 correctly increment feet and set inches to 0', () {
      // 1 foot = 12 inches = 30.48 cm
      // Let's test inches around 11.45 .. 11.99
      for (int feet = 3; feet <= 8; feet++) {
        for (final frac in [11.45, 11.49, 11.50, 11.51, 11.80, 11.95, 11.99]) {
          final totalInches = (feet * 12) + frac;
          final cm = totalInches * 2.54;
          final res = HowbodyHeightConverter.cmToFeetInches(cm);

          expect(
            res.inches >= 0 && res.inches <= 11,
            isTrue,
            reason: 'Rollover failed for frac=$frac: yielded ${res.feet}ft ${res.inches}in',
          );

          if (frac >= 11.5) {
            // Should round up to next foot, inches = 0
            expect(res.feet, equals(feet + 1), reason: 'Expected foot increment for frac=$frac');
            expect(res.inches, equals(0), reason: 'Expected 0 inches for frac=$frac');
          } else {
            // Should round to 11 inches
            expect(res.feet, equals(feet));
            expect(res.inches, equals(11));
          }
        }
      }
    });

    test('Roundtrip stability: cm -> (ft, in) -> cm differs by at most 1.27 cm (0.5 inch)', () {
      // Since imperial integers are rounded to nearest whole inch, maximum deviation
      // is half an inch = 0.5 * 2.54 = 1.27 cm.
      for (double cm = 100.0; cm <= 250.0; cm += 0.25) {
        final imp = HowbodyHeightConverter.cmToFeetInches(cm);
        final roundtripCm = HowbodyHeightConverter.feetInchesToCm(imp.feet, imp.inches);

        final diff = (cm - roundtripCm).abs();
        expect(
          diff <= 1.270001,
          isTrue,
          reason: 'Roundtrip error too high: initial $cm cm, roundtrip $roundtripCm cm (diff: $diff)',
        );
      }
    });

    test('Exact roundtrip bijection: (ft, in) -> cm -> (ft, in) for all valid imperial heights', () {
      // For any valid integer feet and inches, converting to cm and back MUST be an exact bijection
      for (int feet = 3; feet <= 8; feet++) {
        for (int inches = 0; inches <= 11; inches++) {
          final cm = HowbodyHeightConverter.feetInchesToCm(feet, inches);
          final back = HowbodyHeightConverter.cmToFeetInches(cm);

          expect(back.feet, equals(feet), reason: 'Feet mismatch for $feet ft $inches in');
          expect(back.inches, equals(inches), reason: 'Inches mismatch for $feet ft $inches in');
        }
      }
    });
  });

  group('Adversarial Text Input & Controller Handling in HowbodyLinkSheet Logic', () {
    test('Simulate empty, null, and non-numeric input handling for height', () {
      final nonNumericInputs = [
        '',
        '   ',
        'abc',
        '175cm',
        '5\'11"',
        '--175',
        'NaN',
        'null',
      ];

      for (final input in nonNumericInputs) {
        final parsedDouble = double.tryParse(input.trim());
        expect(
          parsedDouble == null || !HowbodyHeightConverter.isValidHeightCm(parsedDouble),
          isTrue,
          reason: 'Non-numeric input "$input" was unexpectedly considered valid',
        );
      }
    });

    test('Simulate imperial text controller parsing with partial / missing inputs', () {
      final scenarios = [
        {'feet': '', 'inches': ''}, // 0 ft 0 in = 0 cm -> invalid
        {'feet': '5', 'inches': ''}, // 5 ft 0 in = 152.4 cm -> valid
        {'feet': '', 'inches': '10'}, // 0 ft 10 in = 25.4 cm -> invalid
        {'feet': '-5', 'inches': '5'}, // negative feet -> invalid
        {'feet': 'abc', 'inches': 'def'}, // non-numeric -> invalid
      ];

      for (final sc in scenarios) {
        final feet = int.tryParse(sc['feet']!.trim()) ?? 0;
        final inches = int.tryParse(sc['inches']!.trim()) ?? 0;
        final cm = HowbodyHeightConverter.feetInchesToCm(feet, inches);

        final isValid = HowbodyHeightConverter.isValidHeightCm(cm);
        if (sc['feet'] == '5' && sc['inches'] == '') {
          expect(isValid, isTrue); // 152.4 cm is valid
        } else {
          expect(isValid, isFalse, reason: 'Expected scenario $sc to be invalid');
        }
      }
    });

    test('DEFECT FINDING: cmToFeetInches throws UnsupportedError when given NaN or Infinity', () {
      expect(
        () => HowbodyHeightConverter.cmToFeetInches(double.nan),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => HowbodyHeightConverter.cmToFeetInches(double.infinity),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
