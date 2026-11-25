# OT Risk and Correlation

## Overview

The Mini-SOC uses deterministic risk scoring to prioritize OT events according to operational context.

Instead of treating every alert independently, the project combines unauthorized activity, asset criticality, threat-intelligence context, and process anomalies to produce progressively higher-confidence detections.

## Risk Model

| Detection Context | Risk |
|---|---:|
| Unauthorized read against critical OT asset | 60 |
| Unauthorized write against critical OT asset | 80 |
| Known IOC communicating with critical asset | 90 |
| Unauthorized manipulation correlated with process anomaly | 100 |

The objective is to make alert priority reflect OT impact rather than only individual rule severity.

## Risk 60 — Unauthorized Read

Unauthorized Modbus reads targeting critical OT assets are assigned a risk score of 60.

This provides visibility into suspicious reconnaissance or unauthorized data access without treating it at the same severity as process manipulation.

## Risk 80 — Unauthorized Write

Rule `140100` represents an unauthorized Modbus write against a critical OT asset.

Example:

```text
ATTACKER01
10.10.50.10
        |
        | unauthorized Modbus write
        v
OT-PLC01
10.10.40.41
```

This produces:

```text
Risk: 80
```

Representative evidence:

`test-data/wazuh/risk80-unauthorized-write.json`

## Risk 90 — Threat-Intelligence Context

The controlled red-team source:

```text
10.10.50.10
```

is present in the local OT threat-intelligence list.

When a known IOC communicates with a critical OT asset, the event can be assigned a risk score of 90.

This provides an independent enrichment path that can be correlated with protocol-level activity.

Representative evidence:

`test-data/wazuh/threat-intel-ioc.json`

## Process Anomaly Detection

Rule `110511` detects abnormal process-setpoint behavior.

The OpenPLC source defines:

```text
LEVEL_SP -> %QW3
```

Some monitoring telemetry represents the observed Modbus location as:

```text
register:4
```

The repository preserves both values exactly because they come from different addressing representations.

The monitoring layer should not silently rewrite one representation into the other.

Representative evidence:

`test-data/wazuh/process-anomaly-level-sp.json`

## Risk 100 — Cyber / Process Correlation

Rule `110512` represents the highest-confidence correlation stage.

It combines:

- unauthorized manipulation
- a critical OT target
- abnormal process context
- temporal proximity

The result is:

```text
Risk: 100
Confidence: high
```

This represents a scenario where malicious or unauthorized network activity is no longer evaluated only as a cyber event. It is correlated with evidence of abnormal industrial process behavior.

## Correlation Across Connections

The correlation logic is temporal and contextual.

The events involved do not need to share the same Zeek UID.

For example, an unauthorized attacker connection may generate a risk-80 write alert while process telemetry from another monitored connection records the abnormal setpoint condition.

The correlation engine combines these events within the defined operational window.

This is deliberate behavior rather than an inconsistency.

## Example Risk-100 Sequence

A preserved sequence demonstrates the correlation path:

```text
Unauthorized critical-asset write
        |
        v
Risk 80 / Rule 140100
        |
        +----------------------+
                               |
Process setpoint anomaly       |
        |                      |
        v                      |
Rule 110511                    |
        |                      |
        +----------------------+
                 |
                 v
        Rule 110512
          Risk 100
```

Representative sequence:

`test-data/wazuh/risk100-sequence.json`

## Incident Aggregation

The Python incident aggregator consumes relevant Wazuh alerts including:

- `130100`
- `140100`
- `110511`
- `110512`

It uses:

- a 60-second correlation window
- a 120-second cooldown
- mandatory presence of rule `110512`

When the high-confidence condition is satisfied, it writes a structured incident to:

```text
/var/log/ot-incidents.json
```

Wazuh then re-ingests the generated incident and raises rule:

```text
160160
```

Representative evidence:

`test-data/wazuh/incident-aggregation.json`

## Detection Hierarchy

The project therefore implements the following hierarchy:

```text
Raw OT telemetry
        |
        v
Individual detection
        |
        v
Asset / IOC enrichment
        |
        v
Deterministic risk score
        |
        v
Cyber / process correlation
        |
        v
Risk-100 detection
        |
        v
Aggregated OT incident
```

## Key Design Principle

A high-risk OT incident should not depend on a single isolated alert.

The project increases confidence by combining multiple independent sources of context:

- protocol behavior
- source authorization
- asset criticality
- threat intelligence
- process state
- event timing

This reduces noise and makes the final incident more meaningful for OT security operations.
