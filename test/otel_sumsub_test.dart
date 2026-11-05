// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_sumsub/otel_sumsub.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_sumsub-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('applicants.get records level + review + country', () async {
    await tracedSumsub<String>(
      operation: 'applicants.get',
      levelName: 'basic-kyc-level',
      invoke: () async => const SumsubCallResult(
        value: 'ok',
        result: SumsubResult(
          applicantId: 'a-1',
          reviewStatus: 'completed',
          reviewAnswer: 'GREEN',
          levelName: 'basic-kyc-level',
          applicantKind: 'individual',
          country: 'DE',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('sumsub applicants.get')!);
    expect(a['sumsub.applicant.id'], 'a-1');
    expect(a['sumsub.review.answer'], 'GREEN');
    expect(a['sumsub.level.name'], 'basic-kyc-level');
    expect(a['sumsub.country'], 'DE');
  });

  test('RED FINAL sets span error', () async {
    await tracedSumsub<String>(
      operation: 'applicants.set_review_result',
      invoke: () async => const SumsubCallResult(
        value: 'ok',
        result: SumsubResult(
          reviewAnswer: 'RED',
          reviewRejectType: 'FINAL',
        ),
      ),
    );
    final s = spans.findSpanByName('sumsub applicants.set_review_result')!;
    expect(s.status, SpanStatusCode.Error);
    final a = attrsOf(s);
    expect(a['sumsub.review.reject_type'], 'FINAL');
  });

  test('transactions.submit records risk + aml', () async {
    await tracedSumsub<String>(
      operation: 'transactions.submit',
      invoke: () async => const SumsubCallResult(
        value: 'ok',
        result: SumsubResult(
          txnRiskScore: 73,
          amlHits: 2,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('sumsub transactions.submit')!);
    expect(a['sumsub.transaction.risk_score'], 73);
    expect(a['sumsub.aml.hits'], 2);
  });

  test('suppression skips spans', () async {
    await runWithoutSumsubInstrumentationAsync(() async {
      await tracedSumsub<String>(
        operation: 'applicants.list',
        invoke: () async => const SumsubCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('sumsub '), isEmpty);
  });
}
