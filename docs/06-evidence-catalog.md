# Evidence Catalog

## Provenance

The images in `assets/screenshots/` were selected from the project's Google Drive `screenshots` folder and renamed for stable repository links. They are operational evidence from the lab, not recreated mockups.

## Catalog

| Repository file | Source title | Supports |
|---|---|---|
| `01-hmi-process-overview.jpg` | `HMI UPGRADED.png` | Ignition HMI and simulated process view |
| `02-historian-baseline.jpg` | `Normal PLC01 process behavior recorded by the OT Historian.png` | Legitimate OT baseline and InfluxDB history |
| `03-modbus-recon-detection.jpg` | `Figure - End-to-End Detection of Unauthorized Modbus Reconnaissance from ATTACKER01 by Zeek and Wazuh 3.png` | Zeek-to-Wazuh reconnaissance detection chain |
| `04-unauthorized-modbus-write.jpg` | `Figure - Detection of Unauthorized Modbus Control Command in Wazuh SIEM.png` | Unauthorized control command detection |
| `05-critical-process-correlation.jpg` | `rule 110512.png` | Critical process-aware correlation |
| `06-incident-aggregation.jpg` | `Aggregate.png` | Incident aggregation and deduplication output |
| `07-bounded-pfsense-containment.jpg` | `blocking using firewall.png` | Scoped pfSense containment evidence |
| `08-conpot-deception-service.jpg` | `Conpot Modbus deception service on is intentionally exposed and reachable.png` | Intentional deception exposure |

## Evidence rules

- Keep original timestamps visible when they matter to a correlation claim.
- Redact credentials, tokens and unrelated personal data before public release.
- Do not crop away source, destination, rule ID or event time when those fields support the claim.
- Do not use one screenshot to claim an end-to-end result if the upstream and downstream timestamps cannot be aligned.
- Preserve the original Drive evidence separately from renamed repository copies.

