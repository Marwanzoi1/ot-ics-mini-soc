# Detection Engineering

## Detection philosophy

The rules do not label every Modbus write as malicious. They combine behavior with context:

- Who initiated the action?
- Which PLC or service was targeted?
- Was the source approved?
- Which function code and process variable were involved?
- Was the value inside an approved range?
- Did the behavior repeat?
- Is the source known to local threat context?
- How critical is the target asset?

This approach reduces the false-positive rate and makes the alert explainable.

## Main rule families

| Rule ID | Level | Purpose |
|---|---:|---|
| `100101` | 12 | Unauthorized Modbus write to the PLC |
| `100102` | 9 | Unauthorized Modbus read |
| `100104` | 11 | Repeated unauthorized reads |
| `110511` | 10 | Setpoint outside the approved range |
| `110512` | 15 | Critical process anomaly + unauthorized manipulation correlation |
| `120001` | 9 | Modbus interaction with Conpot |
| `120002` | 11 | Repeated honeypot interactions |
| `130100/130101` | 12-13 | Local threat-intelligence correlation |
| `140100/140101/140102` | 11-15 | Risk scoring by criticality and context |
| `160160` | 15 | Critical aggregated incident re-ingested into Wazuh |
| `160200/160210/160220` | 12-13 | Zeek, SOC and Conpot integrity monitoring |
| `170100-170130` | 9-14 | Identity, SSH, account, privilege and FIM correlation |

## Unauthorized Modbus activity

Rule `100101` detects writes to `OT-PLC01` from a source that is not approved as an engineering station. The rule covers observed `WRITE_SINGLE_COIL` and `WRITE_SINGLE_REGISTER` operations.

Rule `100102` detects unauthorized reads. Rule `100104` increases severity when the same behavior repeats within a short window, separating an isolated read from sustained reconnaissance.

## Process-aware correlation

Network detection alone does not reveal whether the value being changed is operationally abnormal. The lab therefore uses register-change telemetry to add process context.

`110511` identifies a setpoint outside the approved operating range. `110512` correlates that process anomaly with unauthorized manipulation against a critical asset. The validated critical case receives a risk score of `100/100` and a level-15 alert.

The real event order mattered: the process anomaly was indexed milliseconds before the related unauthorized activity. The final correlation logic was adapted to the observed order rather than an assumed order from synthetic log testing.

## MITRE ATT&CK for ICS mapping

Mapping is applied only when supported by the actual behavior:

| Scenarios | Behavior | Mapping intent |
|---|---|---|
| A02/A03 | Modbus reading and reconnaissance | Discovery / remote system information discovery |
| A04 | Unauthorized coil write | Unauthorized message / command message |
| A05 | Unauthorized setpoint write | Unauthorized message + modify parameter |
| A06 | Historian correlation | Contextual evidence for manipulation |
| A07/A08 | Honeypot interaction/probing | Depends on the observed request |
| A01/A09 | Legitimate activity | Negative control; no adversary technique assigned |

## Threat intelligence and deception

A local CDB list contains controlled lab indicators. `ATTACKER01` is intentionally registered as a known test source. This demonstrates enrichment and correlation but is not presented as a live external intelligence feed.

Conpot events are decoded into source/port context. Rule `120001` detects an interaction and `120002` detects repeated probing.

## Risk scoring and incident aggregation

Asset criticality and context produce different priorities for reading, writing and known-source activity. The lab validated `60/100`, `80/100`, `90/100` and `100/100` cases.

The incident aggregator monitors Wazuh alerts, groups related events in a short time window, calculates a final score/confidence and writes one structured incident record. A cooldown avoids duplicating incidents during repeated execution of the same scenario. Wazuh monitors the aggregated incident file and converts critical records into native rule `160160` alerts.

## SOC resilience and identity

The lab monitors the monitoring system itself:

- Zeek service unavailable;
- Conpot service unavailable;
- Wazuh agent disconnected;
- critical Zeek/Wazuh/Conpot configuration changed;
- sensitive sudo activity;
- repeated SSH authentication failures;
- local account creation, modification and deletion;
- identity + FIM correlation for an attributed `local.zeek` change.

## Bounded response

The response workflow adds a high-confidence source to a dedicated pfSense block table and removes it automatically after a defined period. Response evidence includes the triggering alert, action log, firewall state and post-action connectivity tests.

The design deliberately avoids aggressive automation. A wrong block in OT can be more damaging than the event it responds to; therefore containment is scoped, logged, reversible and tested against approved flows.

