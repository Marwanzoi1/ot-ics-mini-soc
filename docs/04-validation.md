# A01-A10 Validation Matrix

## Method

Each scenario defines a source, target, expected signal, success criterion, latency target where relevant, and required evidence. The test suite includes positive detections and negative controls.

| ID | Scenario | Source -> target | Expected rule/evidence | Success criterion | Target | Observed result |
|---|---|---|---|---|---:|---|
| A01 | Normal OT baseline | `ENG-WS01` -> PLC/historian | No targeted critical rules | Normal control and polling work without critical false positives | N/A | PASS |
| A02 | Unauthorized Modbus read | `ATTACKER01` -> `OT-PLC01:502` | `100102` | Unauthorized read is visible in Zeek and Wazuh | <= 10 s | PASS; approximately 1 s |
| A03 | Repeated unauthorized reads | `ATTACKER01` -> `OT-PLC01:502` | `100104` | Repeated behavior becomes a higher-severity alert | <= 15 s | PASS |
| A04 | Unauthorized coil write | `ATTACKER01` -> `OT-PLC01:502` | `100101` | Level-12 unauthorized-write alert | <= 10 s | PASS |
| A05 | Unauthorized register/setpoint write | `ATTACKER01` -> `OT-PLC01:502` | `100101` + process context | Write detected; relevant process variable can be correlated | <= 10 s | PASS |
| A06 | Process correlation | Attacker, PLC and historian | Wazuh + InfluxDB timestamps | Security and historian evidence align without overstating physical impact | <= 30 s window | PASS |
| A07 | Conpot Modbus interaction | `ATTACKER01` -> `CONPOT01:5020` | `120001` | Honeypot interaction alert | <= 10 s | PASS |
| A08 | Repeated Conpot probing | `ATTACKER01` -> `CONPOT01:5020` | `120002` | Frequency threshold produces level-11 alert | <= 15 s | PASS |
| A09 | Legitimate engineering action | `ENG-WS01` -> `OT-PLC01:502` | No `100101` | Authorized write succeeds without a critical unauthorized-write alert | N/A | PASS |
| A10 | Bounded automated response | `ATTACKER01` -> trigger target | Wazuh alert + response log + pfSense evidence | Only attacker blocked; approved flows remain; block expires | Block <= 30 s | PASS |

## Evidence requirements

- Attacker command output where applicable.
- Zeek connection/Modbus/register telemetry.
- Wazuh alert details and timestamps.
- InfluxDB graph or table for process correlation.
- Conpot log for deception scenarios.
- pfSense block state and response action log.
- Post-containment connectivity checks for `ENG-WS01` and `OT-HIST01`.

## Key findings

### Negative controls matter

A01 and A09 prove that the system does more than fire alerts. Normal OT traffic remains available, and an authorized engineering write is distinguished from an equivalent attacker write.

### Correlation is contextual, not physical proof

For A06, timestamp alignment between Wazuh and InfluxDB supports investigation. It does not independently prove physical impact. That distinction prevents the documentation from overstating what a virtualized historian trace can establish.

### Containment is reversible

A10 inserts the attacker into the pfSense block table and later removes it automatically. The validation also checks that legitimate engineering and historian traffic remain available.

## Evidence images

- [`03-modbus-recon-detection.jpg`](../assets/screenshots/03-modbus-recon-detection.jpg)
- [`04-unauthorized-modbus-write.jpg`](../assets/screenshots/04-unauthorized-modbus-write.jpg)
- [`05-critical-process-correlation.jpg`](../assets/screenshots/05-critical-process-correlation.jpg)
- [`07-bounded-pfsense-containment.jpg`](../assets/screenshots/07-bounded-pfsense-containment.jpg)

