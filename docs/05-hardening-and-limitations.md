# Hardening and Honest Scope

## Exposure-driven hardening

The project used connectivity tests and service inventories to identify gaps instead of assuming that segmentation was complete.

| Component | Hardening objective |
|---|---|
| pfSense | Block `ATTACKER01 -> OT-PLC01:502` while preserving `ENG-WS01 -> OT-PLC01:502` |
| `CONPOT01` | Block SSH from the attack zone while keeping intentional deception services reachable |
| `ENG-WS01` | Remove unused FUXA/Avahi and temporary NAT where unnecessary; require administration through the bastion |
| `SOC-SIEM01` | Restrict API/enrollment exposure; retain only required NTP and Wazuh paths |
| `OT-SENSOR01` | Restrict SSH and Zeek management/metrics listeners |
| `OT-HIST01` | Restrict SSH and TCP/8086 to required sources |
| `OT-PLC01` | Restrict SSH/8443, control UDP/33333 and close attacker access to TCP/502 |
| `JUMP-HOST01` | Keep one NIC, use SSH keys, minimize SSH features and allow only operational Wazuh telemetry after enrollment |

The Drive evidence contains later post-hardening captures, but the supplied report's hardening table still describes several actions as pending. Treat the report as the baseline and publish final hardening claims only with the corresponding regression evidence in the repository.

## Regression priorities

After each policy change, verify:

1. `ENG-WS01 -> OT-PLC01:502` remains allowed.
2. `ATTACKER01 -> OT-PLC01:502` is blocked.
3. `ENG-WS01 -> OT-PLC01:8443` remains allowed.
4. `ENG-WS01 -> OT-HIST01:8086` remains allowed.
5. `ATTACKER01 -> CONPOT01:5020` remains intentionally reachable.
6. `ATTACKER01 -> CONPOT01:22` is blocked.
7. `JUMP-HOST01 -> ENG-WS01:22` remains allowed.
8. `JUMP-HOST01 -> OT-PLC01:502` remains blocked.
9. Wazuh agents and Zeek telemetry remain operational.
10. Representative detections still produce their expected alerts.

## Limitations

- The lab is virtualized and cannot stand in for product qualification or safety certification.
- Asset count, traffic volume and event timing are controlled.
- The enterprise/Level 4 layer is logical rather than a full IT deployment.
- Frequency and health thresholds require production tuning.
- Historian correlation is contextual evidence, not proof of physical consequence.
- High availability, redundant networks, MFA, centralized OT identity and offline backups are outside the implemented scope.
- The local CDB indicator list demonstrates a mechanism, not a live threat-intelligence service.
- Deployment configurations and scripts are not yet complete in this package, so reproducibility is partial.

## What should be published next

The highest-value improvement is not another dashboard. It is reproducibility:

1. sanitized Wazuh rules and decoders;
2. Zeek scripts and bridge configuration;
3. pfSense aliases/rules and response implementation;
4. incident aggregator code and tests;
5. automated A01-A10 regression scripts;
6. redacted sample events that let another analyst test the logic offline.

