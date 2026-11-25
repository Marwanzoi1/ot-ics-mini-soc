#!/usr/bin/env python3

import json
import subprocess
import time
from collections import deque
from datetime import datetime

ALERTS = "/var/ossec/logs/alerts/alerts.json"
OUTPUT = "/var/log/ot-incidents.json"

WINDOW = 60
COOLDOWN = 120

RELEVANT_RULES = {
    "130100",
    "140100",
    "110511",
    "110512",
}

events = deque()
last_incident = {}


def now_epoch():
    return time.time()


def get_target(alert):
    try:
        return alert["data"]["id"]["resp_h"]
    except Exception:
        return None


def get_source(alert):
    try:
        return alert["data"]["id"]["orig_h"]
    except Exception:
        return None


def rule_id(alert):
    return str(alert.get("rule", {}).get("id", ""))


def purge_old():
    cutoff = now_epoch() - WINDOW
    while events and events[0][0] < cutoff:
        events.popleft()


def emit_incident(trigger):

    source = get_source(trigger)
    target = get_target(trigger)

    if not source or not target:
        return

    key = f"{source}->{target}"

    if now_epoch() - last_incident.get(key, 0) < COOLDOWN:
        return

    related = []

    for event_time, alert in events:
        rid = rule_id(alert)
        event_target = get_target(alert)

        if event_target != target:
            continue

        related.append(alert)

    evidence_rules = sorted({
        rule_id(a)
        for a in related
        if rule_id(a) in RELEVANT_RULES
    })

    # 110512 is our mandatory high-confidence trigger.
    if "110512" not in evidence_rules:
        return
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    incident_id = f"OT-{stamp}"
    incident = {
        "event_type": "ot_incident",
        "incident_id": incident_id,
        "source_ip": source,
        "target_ip": target,
        "target_asset": "OT-PLC01" if target == "10.10.40.41" else "UNKNOWN",
        "severity": "critical",
        "risk_score": 100,
        "confidence": "high",
        "evidence_rules": evidence_rules,
        "evidence_count": len(related),
        "attack_techniques": [
            "T1692.001",
            "T0836"
        ],
        "summary": (
            "High-confidence unauthorized OT process manipulation "
            "against critical PLC with correlated process anomaly"
        ),
        "created_at": datetime.now().astimezone().isoformat()
    }

    with open(OUTPUT, "a", encoding="utf-8") as f:
        f.write(json.dumps(incident) + "\n")

    last_incident[key] = now_epoch()

    print(
        f"[INCIDENT] {incident_id} "
        f"{source} -> {target} "
        f"evidence={evidence_rules}",
        flush=True
    )


def process(alert):
    rid = rule_id(alert)

    if rid not in RELEVANT_RULES:
        return

    events.append((now_epoch(), alert))
    purge_old()

    if rid == "110512":
        emit_incident(alert)


def main():
    proc = subprocess.Popen(
        ["tail", "-n", "0", "-F", ALERTS],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1
    )

    print("[+] OT incident aggregator started", flush=True)

    for line in proc.stdout:
        try:
            alert = json.loads(line)
            process(alert)
        except json.JSONDecodeError:
            continue
        except Exception as exc:
            print(f"[!] Error: {exc}", flush=True)


if __name__ == "__main__":
    main()
