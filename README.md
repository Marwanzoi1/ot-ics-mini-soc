# OT/ICS Mini-SOC

A laboratory OT/ICS cybersecurity project implementing network monitoring, context-aware detection, risk correlation, incident aggregation, and bounded automated containment around a simulated industrial process.

## 1. Project Objectives

The Mini-SOC was designed to demonstrate an end-to-end OT security monitoring workflow:

1. Observe industrial Modbus/TCP traffic.
2. Identify unauthorized clients and suspicious operations.
3. Apply OT asset context and threat intelligence.
4. Reduce false positives by distinguishing authorized engineering activity.
5. Correlate cyber events with process-state anomalies.
6. Assign deterministic risk scores.
7. Aggregate high-confidence events into critical incidents.
8. Execute bounded and reversible network containment.

## 2. Lab Architecture

The environment was implemented as a segmented virtual OT/ICS lab.

| Asset | IP | Role |
|---|---|---|
| JUMP-HOST01 | 10.10.10.40 | IDMZ administrative bastion |
| CONPOT01 | 10.10.10.30 | OT honeypot |
| SOC-SIEM01 | 10.10.20.20 | Wazuh manager, indexer, dashboard and incident aggregation |
| OT-SENSOR01 | 10.10.20.40 | Zeek sensor and Wazuh agent |
| ENG-WS01 | 10.10.30.20 | Engineering workstation |
| OT-HIST01 | 10.10.40.30 | Historian / InfluxDB |
| OT-PLC01 | 10.10.40.41 | OpenPLC / Modbus TCP |
| ATTACKER01 | 10.10.50.10 | Controlled Kali attack host |
| pfSense-ICS | 10.10.20.1 | Segmentation firewall and containment enforcement |

Network zones:

- `10.10.10.0/24` — IDMZ
- `10.10.20.0/24` — SOC / supervision
- `10.10.30.0/24` — engineering
- `10.10.40.0/24` — OT
- `10.10.50.0/24` — controlled test / attacker network

## 3. OT Monitoring Architecture

OT-SENSOR01 operates as an inline Layer-2 bridge on the monitored engineering-to-PLC path.

Zeek monitors the bridge interface `br0` and loads the built-in Modbus analyzer together with Modbus memory-map tracking.

Relevant Zeek artifacts:

```text
zeek/
├── local.zeek
├── bridge-and-status.txt
└── config/
```

The upstream Zeek `track-memmap.zeek` policy is referenced by configuration but is not included as custom project code.

## 4. Detection Pipeline

The main detection pipeline is:

Modbus/TCP traffic
        |
        v
OT-SENSOR01 / Zeek
        |
        v
JSON Modbus telemetry
        |
        v
Wazuh custom OT rules
        |
        +--> Source authorization context
        +--> Critical-asset context
        +--> Threat-intelligence context
        +--> Process-variable context
        |
        v
Deterministic risk scoring
        |
        v
Temporal / process correlation
        |
        v
Critical OT incident

Important rules include:

| Rule | Purpose |
|---|---|
| 100101 | Unauthorized Modbus write |
| 100102 | Unauthorized Modbus read |
| 100104 | Repeated unauthorized reads |
| 110511 | Process setpoint anomaly |
| 110512 | High-confidence cyber/process correlation |
| 120001 | Conpot interaction |
| 120002 | Repeated honeypot interaction |
| 130100 | Known threat-intelligence source |
| 140100 | Unauthorized write to critical OT asset |
| 140101 | Unauthorized read to critical OT asset |
| 140102 | Known IOC communicating with critical asset |
| 160160 | Critical aggregated OT incident |

Custom detection rules are stored under `wazuh/rules/`.

## 5. Risk Model

The project applies deterministic OT risk scoring.

| Scenario | Risk |
|---|---:|
| Unauthorized read against critical asset | 60 |
| Unauthorized write against critical asset | 80 |
| Known IOC communicating with critical asset | 90 |
| Unauthorized manipulation + process anomaly + critical asset | 100 |

This allows the SIEM to prioritize OT events using operational context instead of relying only on individual alert severity.

## 6. Process-Aware Detection

The OpenPLC process contains tank level, flow, pressure, valves, pump state, alarms and a level setpoint.

Selected variables:

- HMI_START — `%QX0.0`
- HMI_STOP — `%QX0.1`
- HMI_RESET — `%QX0.2`
- AUTO_MODE — `%QX0.3`
- PUMP_RUN — `%QX1.0`
- INLET_VALVE — `%QX1.1`
- OUTLET_VALVE — `%QX1.2`
- ALARM_ACTIVE — `%QX2.3`
- TANK_LEVEL — `%QW0`
- FLOW_RATE — `%QW1`
- PRESSURE — `%QW2`
- LEVEL_SP — `%QW3`

The authoritative PLC logic and variable mapping are stored under `openplc/`.

### Addressing Note

The PLC source maps `LEVEL_SP` to `%QW3`.

Some Zeek/Wazuh telemetry represents the observed Modbus register as `register:4`. Both values are preserved exactly because they originate from different addressing representations in the PLC/application and monitoring layers.

## 7. False-Positive Reduction

False-positive reduction was based on operational context instead of simply lowering alert severity.

Techniques used include:

- authorized OT client allowlisting
- source and destination context
- critical-asset classification
- Modbus function context
- process-variable and value context
- repeated-event thresholds
- temporal correlation
- incident deduplication and cooldown
- negative-control testing with legitimate engineering traffic

A legitimate engineering write from ENG-WS01 was used as a negative control to confirm that authorized activity did not generate the same unauthorized-write critical detection.

## 8. Incident Aggregation

A Python incident aggregator monitors Wazuh alerts and creates a higher-level OT incident when high-confidence evidence occurs within a defined time window.

Implementation:

`correlation/ot-incident-aggregator.py`

The aggregator:

- consumes Wazuh JSON alerts
- tracks relevant OT detection rules
- uses a 60-second correlation window
- applies a 120-second cooldown
- requires high-confidence rule `110512`
- writes structured incidents to `/var/log/ot-incidents.json`

The generated incident is then re-ingested by Wazuh and detected by rule `160160`.

Example evidence is available in:

`test-data/wazuh/incident-aggregation.json`

## 9. Automated Containment

The project includes bounded and reversible automated containment.

Workflow:

Wazuh rule `100101`
→ `ot-containment.py`
→ pfSense `WAZUH_BLOCKLIST`
→ temporary block against the OT network
→ automatic removal after timeout

The response validates the source IP before containment and excludes protected OT systems.

The pfSense enforcement scope is:

`<WAZUH_BLOCKLIST> -> 10.10.40.0/24`

Captured A10 execution evidence:

- `2026-08-30T23:43:53` — BLOCK `10.10.50.10` — SUCCESS
- `2026-08-30T23:44:54` — UNBLOCK `10.10.50.10` — SUCCESS
- `2026-08-30T23:47:13` — BLOCK `10.10.50.10` — SUCCESS
- `2026-08-30T23:48:14` — UNBLOCK `10.10.50.10` — SUCCESS

The captured tests therefore demonstrate approximately 61 seconds of bounded and reversible containment.

After successful validation, automated active response was intentionally disabled to avoid unintended disruption in the lab.

The current Wazuh configuration therefore contains:

`<disabled>yes</disabled>`

This represents the post-validation safe state, not the configuration used during the successful A10 execution.

## 10. Example Attack Evidence

A preserved Zeek sample shows ATTACKER01 communicating with OT-PLC01 over Modbus/TCP.

Observed connection:

- Source: `10.10.50.10:45898`
- Destination: `10.10.40.41:502`
- Zeek UID: `Cya56qiuHG6ptpPg`

Observed Modbus sequence:

- `WRITE_SINGLE_REGISTER` request
- `WRITE_SINGLE_REGISTER` response
- `WRITE_SINGLE_COIL` request
- `WRITE_SINGLE_COIL` response
- `WRITE_SINGLE_COIL` request
- `WRITE_SINGLE_COIL` response

Raw evidence:

`test-data/zeek/unauthorized-modbus-write.json`

Corresponding Wazuh evidence demonstrates contextual escalation to risk 80, followed by process-aware correlation to risk 100.

## 11. Repository Structure

```text
OT-ICS-Mini-SOC/
├── architecture/
├── config/
├── correlation/
├── openplc/
├── pfsense/
├── response/
├── screenshots/
├── systemd/
├── test-data/
│   ├── response/
│   ├── wazuh/
│   └── zeek/
├── wazuh/
│   ├── decoders/
│   ├── lists/
│   └── rules/
├── writeups/
└── zeek/
    └── config/

```

## 12. Evidence Included

The repository contains compact evidence rather than complete runtime archives.

Examples include:

- unauthorized Modbus write telemetry
- unauthorized-write Wazuh alerts
- risk-80 critical-asset detections
- process-setpoint anomaly evidence
- risk-100 correlation sequences
- threat-intelligence detections
- aggregated critical OT incidents
- bounded containment execution logs
- representative baseline Modbus traffic
- representative Modbus register-change telemetry

Large raw logs are intentionally excluded from the public repository.

## 13. Security and Sanitization

The public repository intentionally excludes sensitive material.

Not included:

- Wazuh `client.keys`
- pfSense SSH private keys
- TLS private keys
- OpenPLC `.env`
- OpenPLC runtime databases
- passwords
- API tokens
- complete pfSense configuration exports
- complete Wazuh alert archives
- full packet captures
- private VM backups

References to secret file paths may remain in source code when required to document how the implementation works, but the secret material itself is not included.

## 14. Project Scope

This repository represents a controlled educational OT/ICS cybersecurity laboratory.

All attack activity was executed against isolated lab systems created specifically for the project.

The project demonstrates:

- OT network segmentation
- passive industrial protocol monitoring
- detection engineering
- asset-aware SIEM rules
- threat-intelligence enrichment
- false-positive reduction
- process-aware correlation
- deterministic risk scoring
- incident aggregation
- bounded automated containment

It is not intended to be deployed unchanged in a production industrial environment.
