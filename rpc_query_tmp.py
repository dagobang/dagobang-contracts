import json, urllib.request

def rpc(method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request("https://bsc-dataseed.binance.org", data=body, headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

addr = "0xae8ec1b7dc2ce7828ebd269c96fa0533148736ce"
print("latest nonce", rpc("eth_getTransactionCount", [addr, "latest"]))
print("pending nonce", rpc("eth_getTransactionCount", [addr, "pending"]))

hashes = [
 "0x88c29b19877ef83016336e756d5125054149bc1ff686efb227d553f791e81f6f",
 "0x827f4e07ec5b03c29c72ef4dc32852ff68ebe8c6e44b3dbd80ebc0b15c3b8482",
 "0xefb800695b7d7015e070d9df2f8375640b64dbd5f3a1704a8079a19850c3a3a4",
]
for h in hashes:
    rec = rpc("eth_getTransactionReceipt", [h])
    tx = rpc("eth_getTransactionByHash", [h])
    r = rec.get("result") or {}
    t = tx.get("result") or {}
    print("---", h)
    print("status", r.get("status"), "contractAddress", r.get("contractAddress"), "nonce", t.get("nonce"), "block", r.get("blockNumber"))
