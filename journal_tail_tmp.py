import json
path = "ignition/deployments/chain-56/journal.jsonl"
events = []
with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        events.append(json.loads(line))
print(f"total journal events: {len(events)}")
print("--- last 25 journal events (type + futureId + hash/nonce) ---")
for e in events[-25:]:
    out = {
        "type": e.get("type"),
        "futureId": e.get("futureId"),
    }
    for k in ("hash", "nonce", "txHash", "transactionHash"):
        if k in e:
            out[k] = e[k]
    # nested common places
    for nest in ("transaction", "tx", "artifact"):
        if isinstance(e.get(nest), dict):
            t = e[nest]
            for k in ("hash", "nonce", "txHash", "transactionHash"):
                if k in t:
                    out[k] = t[k]
    print(json.dumps(out, ensure_ascii=False))
print("--- deployed_addresses.json ---")
with open("ignition/deployments/chain-56/deployed_addresses.json", encoding="utf-8") as f:
    print(f.read())
