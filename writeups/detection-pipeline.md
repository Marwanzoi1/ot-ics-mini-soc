# OT Detection Pipeline

## Overview

The Mini-SOC converts industrial Modbus/TCP network activity into contextualized OT security detections.

OT-SENSOR01 operates as a transparent Layer-2 bridge on the monitored engineering-to-PLC path. Zeek analyzes traffic crossing the bridge interface `br0`, extracts Modbus/TCP protocol telemetry, and produces structured logs that are consumed by Wazuh.

The objective is not only to detect suspicious Modbus operations, but to enrich them with source authorization, asset criticality, threat-intelligence context, and process-state information.

## Detection Flow

```text
Modbus/TCP traffic
        |
        v
OT-SENSOR01
Transparent Layer-2 bridge
        |
        v
Zeek Modbus analyzer
        |
        v
Structured Modbus telemetry
        |
        v
Wazuh custom OT rules
        |
        +--> Source authorization
        +--> Asset criticality
        +--> Threat intelligence
        +--> Process context
        |
        v
Risk scoring
        |
        v
Temporal / process correlation
        |
        v
High-confidence OT detection
```

## Raw Modbus Telemetry

Zeek provides protocol-aware telemetry including:

- source and destination IP addresses
- source and destination ports
- Zeek connection UID
- Modbus transaction ID
- unit ID
- function type
- request or response direction

A preserved attack sample shows:

```text
10.10.50.10:45898 -> 10.10.40.41:502
UID: Cya56qiuHG6ptpPg
```

The observed Modbus sequence includes:

- `WRITE_SINGLE_REGISTER`
- `WRITE_SINGLE_COIL`
- `WRITE_SINGLE_COIL`

The raw sample is stored in:

`test-data/zeek/unauthorized-modbus-write.json`

## Unauthorized Modbus Operations

Wazuh applies custom rules to distinguish legitimate engineering activity from unauthorized OT operations.

Rule `100101` detects unauthorized Modbus write operations.

Rule `100102` detects unauthorized Modbus read operations.

Rule `100104` detects repeated unauthorized reads.

Authorized engineering clients are excluded using source context and allowlisting.

This is important for false-positive reduction: a Modbus write is not treated as malicious only because it is a write. The source, destination, and operational context are considered before escalating the event.

## Critical Asset Context

The project maintains an OT asset-criticality model.

OT-PLC01:

```text
10.10.40.41
```

is classified as a critical PLC asset.

An unauthorized Modbus write targeting the PLC can therefore be escalated by rule `140100`.

This produces a risk score of:

```text
80
```

Representative evidence:

`test-data/wazuh/risk80-unauthorized-write.json`

## Threat-Intelligence Context

The controlled attacker system:

```text
10.10.50.10
```

is included in the laboratory threat-intelligence list as a known red-team source.

This allows Wazuh to independently enrich activity originating from the attacker network.

Threat-intelligence detections can therefore be correlated with Modbus activity against critical assets.

Representative evidence:

`test-data/wazuh/threat-intel-ioc.json`

## Process-Aware Detection

The OpenPLC process exposes operational variables including:

- tank level
- flow rate
- pressure
- pump state
- valve state
- alarm state
- level setpoint

Rule `110511` detects an abnormal `LEVEL_SP` condition.

The PLC source maps:

```text
LEVEL_SP -> %QW3
```

Some monitoring telemetry represents the observed Modbus register as:

```text
register:4
```

Both representations are retained because they originate from different addressing layers.

Representative process-anomaly evidence:

`test-data/wazuh/process-anomaly-level-sp.json`

## High-Confidence Correlation

Rule `110512` represents the high-confidence cyber/process correlation stage.

It combines:

- unauthorized manipulation
- critical-asset context
- abnormal process state
- temporal proximity

The result is assigned:

```text
Risk: 100
Confidence: high
```

This correlation is not dependent on all evidence sharing the same Zeek UID.

The design intentionally correlates related security and process events occurring within the same operational time window, even when they originate from different monitored connections.

Representative evidence:

`test-data/wazuh/risk100-sequence.json`

## False-Positive Reduction

The detection pipeline reduces false positives through:

- authorized-client allowlisting
- source and destination context
- Modbus function context
- asset criticality
- process-variable context
- repeated-event thresholds
- temporal correlation
- negative-control testing

Legitimate engineering activity from ENG-WS01 is used as a negative control to verify that approved operations do not trigger the same unauthorized-write detection path.

## Relationship to Incident Aggregation

The detection pipeline produces the individual security events consumed by the Python incident aggregator.

The aggregator monitors relevant rules including:

- `130100`
- `140100`
- `110511`
- `110512`

Rule `110512` is required for the high-confidence incident condition.

When the required evidence occurs within the correlation window, the aggregator creates a structured OT incident that is re-ingested by Wazuh and detected by rule `160160`.

## Evidence

Representative detection evidence is available under:

- `test-data/zeek/unauthorized-modbus-write.json`
- `test-data/wazuh/unauthorized-write-rule100101.json`
- `test-data/wazuh/risk80-unauthorized-write.json`
- `test-data/wazuh/threat-intel-ioc.json`
- `test-data/wazuh/process-anomaly-level-sp.json`
- `test-data/wazuh/risk100-sequence.json`
- `test-data/wazuh/incident-aggregation.json`
