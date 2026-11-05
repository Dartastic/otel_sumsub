// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_sumsub/otel_sumsub.dart';

/// Traces Sumsub calls with OpenTelemetry.
///
/// `otel_sumsub` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Sumsub call in
/// [tracedSumsub]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'sumsub-example');

  // Wraps a Sumsub API call in a CLIENT span.
  final sumsubId = await tracedSumsub<String>(
    operation: 'applicants.create',
    levelName: 'example',
    invoke: () async {
      // Make the Sumsub call here, then report what it returned.
      const id = 'sumsub_8f3a2c';
      return const SumsubCallResult(
          value: id,
          result: SumsubResult(
              applicantId: 'applicant_8f3a2c',
              reviewStatus: 'init',
              reviewAnswer: 'GREEN',
              reviewRejectType: 'FINAL',
              levelName: 'example',
              applicantKind: 'individual',
              country: 'example',
              txnRiskScore: 1,
              amlHits: 1,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedSumsub applicants.create returned $sumsubId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSumsubInstrumentationAsync.
  await runWithoutSumsubInstrumentationAsync(
    () => tracedSumsub<String>(
      operation: 'applicants.create',
      levelName: 'example',
      invoke: () async {
        const id = 'sumsub_8f3a2c';
        return const SumsubCallResult(
            value: id,
            result: SumsubResult(
                applicantId: 'applicant_8f3a2c',
                reviewStatus: 'init',
                reviewAnswer: 'GREEN',
                reviewRejectType: 'FINAL',
                levelName: 'example',
                applicantKind: 'individual',
                country: 'example',
                txnRiskScore: 1,
                amlHits: 1,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
