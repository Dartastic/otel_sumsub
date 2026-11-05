// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_sumsub_suppression.dart';

const _tracerName = 'dartastic_otel_libs_sumsub';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class SumsubResult {
  /// Creates a result.
  const SumsubResult({
    this.applicantId,
    this.reviewStatus,
    this.reviewAnswer,
    this.reviewRejectType,
    this.levelName,
    this.applicantKind,
    this.country,
    this.txnRiskScore,
    this.amlHits,
    this.requestId,
    this.statusCode,
  });

  /// `applicantId`.
  final String? applicantId;

  /// `init` / `pending` / `queued` / `prechecked` / `onHold` /
  /// `completed`.
  final String? reviewStatus;

  /// `GREEN` / `RED`.
  final String? reviewAnswer;

  /// `FINAL` / `RETRY` when reviewAnswer == RED.
  final String? reviewRejectType;

  /// Level name (Sumsub's verification flow name) — drives cost.
  final String? levelName;

  /// `individual` / `company`.
  final String? applicantKind;

  /// ISO 3166 country.
  final String? country;

  /// Transaction-monitoring risk score (0-100).
  final int? txnRiskScore;

  /// AML hits returned.
  final int? amlHits;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class SumsubCallResult<T> {
  /// Creates a call result.
  const SumsubCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final SumsubResult? result;
}

/// Wraps a Sumsub API call in a CLIENT span. [operation] is one of
/// `applicants.create`, `applicants.get`, `applicants.update`,
/// `applicants.add_id_doc`, `applicants.set_pending`,
/// `applicants.set_review_result`, `applicants.list`,
/// `accessToken.create`, `levels.list`, `transactions.submit`,
/// `transactions.list`, `aml.search`, `webhooks.list`,
/// `webhooks.create`.
Future<T> tracedSumsub<T>({
  required String operation,
  required Future<SumsubCallResult<T>> Function() invoke,
  String? levelName,
}) async {
  if (sumsubInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'sumsub',
    'rpc.method': operation,
    'sumsub.operation': operation,
  };
  if (levelName != null) m['sumsub.level.name'] = levelName;

  final span = _tracer().startSpan(
    'sumsub $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.applicantId != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.applicant.id',
          r.result!.applicantId!,
        ));
      }
      if (r.result!.reviewStatus != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.review.status',
          r.result!.reviewStatus!,
        ));
      }
      if (r.result!.reviewAnswer != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.review.answer',
          r.result!.reviewAnswer!,
        ));
        if (r.result!.reviewAnswer == 'RED') {
          span.setStatus(
            SpanStatusCode.Error,
            'Sumsub review RED',
          );
        }
      }
      if (r.result!.reviewRejectType != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.review.reject_type',
          r.result!.reviewRejectType!,
        ));
      }
      if (r.result!.levelName != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.level.name',
          r.result!.levelName!,
        ));
      }
      if (r.result!.applicantKind != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.applicant.kind',
          r.result!.applicantKind!,
        ));
      }
      if (r.result!.country != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.country',
          r.result!.country!,
        ));
      }
      if (r.result!.txnRiskScore != null) {
        extras.add(OTelAPI.attributeInt(
          'sumsub.transaction.risk_score',
          r.result!.txnRiskScore!,
        ));
      }
      if (r.result!.amlHits != null) {
        extras.add(OTelAPI.attributeInt(
          'sumsub.aml.hits',
          r.result!.amlHits!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'sumsub.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Sumsub HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
