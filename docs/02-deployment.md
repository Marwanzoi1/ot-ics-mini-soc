# Deployment and Telemetry Flow

## Industrial process

`OT-PLC01` runs OpenPLC Runtime. Modbus/TCP is exposed on TCP/502. The simulated process provides changing variables that can be displayed in Ignition and stored in InfluxDB without physical equipment.

`ENG-WS01` runs Ignition and represents the authorized engineering/HMI role. It can read and write the approved Modbus variables, use the OpenPLC administrative interface when required, and access the historian.

`OT-HIST01` runs InfluxDB on TCP/8086 and stores process time series. Historian data is used as context during security analysis, not as standalone proof of physical impact.

## Network visibility

`OT-SENSOR01` runs Zeek in standalone mode on the transparent Layer-2 bridge interface `br0`, positioned inline on the monitored engineering-to-PLC path. Zeek passively analyzes traffic crossing the bridge without acting as the Modbus endpoint.

Important telemetry includes:

- connection metadata;
- Modbus read and write functions;
- register-change observations;
- source and destination context;
- service-health state.

## SIEM and correlation

`SOC-SIEM01` hosts the Wazuh manager, indexer and dashboard. The manager receives:

- Zeek JSON logs;
- pfSense firewall logs;
- Conpot events;
- Wazuh agent telemetry from monitored hosts;
- file-integrity events;
- authentication, sudo and account-lifecycle events;
- aggregated OT incident records.

Custom rules are validated before manager restart. The deployment preserves the raw event trail needed to investigate how a high-level incident was produced.

## Deception

`CONPOT01` runs the default Conpot template with an intentionally exposed Modbus deception service. Its log is normalized and ingested by Wazuh.

The security boundary is explicit: the simulated industrial services are exposed by design; the host's real SSH management service is not part of the deception surface and should be restricted.

## Firewall and response

pfSense provides inter-zone routing, policy enforcement and centralized logging. Automated response uses a dedicated block table so the action is:

- scoped to the identified source;
- visible in firewall logs;
- reversible;
- automatically expired;
- regression-tested against approved engineering and historian paths.

## Indicative VM sizing

| VM | vCPU | Target RAM | Note |
|---|---:|---:|---|
| `SOC-SIEM01` | 2 | 4 GB | Prioritize indexer and dashboard |
| `ENG-WS01` | 2 | 2.5-3 GB | Ubuntu Desktop + Ignition |
| `OT-SENSOR01` | 2 | 1.5 GB | Zeek sensor |
| `ATTACKER01` | 2 | 1.5 GB | Start only for controlled tests |
| `OT-PLC01` | 1 | 1 GB | OpenPLC |
| `OT-HIST01` | 1 | 1 GB | InfluxDB |
| `CONPOT01` | 1 | 0.75-1 GB | Honeypot |
| `pfSense-ICS` | 1 | 0.75-1 GB | Firewall and routing |
| `JUMP-HOST01` | 1 | 0.75-1 GB | Ubuntu Server bastion |

These values reflect a resource-constrained lab, not production sizing.
