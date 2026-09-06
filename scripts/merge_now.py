import json

SCRAPED = r"c:\xflws\scripts\scraper-output\scraped_data.json"
INST = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\data\live\instruments.json.php"

with open(SCRAPED, encoding="utf-8") as f:
    scraped = json.load(f)

with open(INST, encoding="utf-8") as f:
    content = f.read()
existing = json.loads(content[content.index("\n")+1:])

sm = {s["ticker"]: s for s in scraped if s.get("ticker")}
updated = 0

for inst in existing:
    t = inst.get("ticker", "")
    if t in sm:
        s = sm[t]
        updated += 1
        if s.get("name") and s["name"] != t:
            inst["name"] = s["name"]
        if s.get("sector"):
            inst["sector"] = s["sector"]
        inst["industry"] = s.get("industry", "")
        inst["website"] = s.get("website", "")
        inst["ceo"] = s.get("ceo", "")
        inst["headquarters"] = s.get("headquarters", "")
        inst["founded"] = s.get("founded", "")
        inst["ipoDate"] = s.get("ipo_date", "")
        inst["isin"] = s.get("isin", "")
        inst["description"] = s.get("description", "")

guard = "<?php http_response_code(404); exit; ?>\n"
with open(INST, "w", encoding="utf-8") as f:
    f.write(guard + json.dumps(existing, indent=4, ensure_ascii=False))

print(f"Updated {updated} instruments with scraped company data")
print(f"Total: {len(existing)} instruments")
