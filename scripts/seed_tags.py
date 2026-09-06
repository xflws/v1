#!/usr/bin/env python3
"""
Add tags to all instruments in instruments.json.php.
Tags control which collections each stock/fund appears in on the Discover page.

Tag mapping:
  sharia      → Sharia-compliant collection
  egx30       → EGX30 companies
  dividend    → Dividend payers
  active      → Most traded
  recent      → Recently listed
  healthcare  → Health care
  metal       → Metal funds
  money-market → Money market
  fixed-income → Fixed income
  equity      → Equity funds
  savings     → Savings
  real-estate → Real estate
  balanced    → Balanced
"""

import json
import os

INST_FILE = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\data\live\instruments.json.php"

with open(INST_FILE, encoding="utf-8") as f:
    content = f.read()

instruments = json.loads(content[content.index("\n")+1:])

# Define tag rules
def get_tags(inst):
    tags = []
    ticker = inst.get("ticker", "")
    sector = inst.get("sector", "").lower()
    kind = inst.get("kind", "")
    index = inst.get("index", "").lower()
    listed = inst.get("listed", "")
    name = inst.get("name", "").lower()
    volume = inst.get("volume", 0)
    currency = inst.get("currency", "")
    
    # EGX30
    if index == "egx30" or ticker in ["COMI", "TMGH", "ETEL", "SWDY", "CCAP", "CPME"]:
        tags.append("egx30")
    
    # Sharia (based on sector/name or known Sharia-compliant stocks)
    sharia_keywords = ["sharia", "islamic", "halal"]
    if any(kw in sector for kw in sharia_keywords) or any(kw in name for kw in sharia_keywords):
        tags.append("sharia")
    # Known Sharia-compliant Egyptian stocks
    if ticker in ["JUFO", "AJWA", "ECAP", "CERA", "AMIA"]:
        tags.append("sharia")
    
    # Dividend payers (known dividend stocks on EGX)
    if ticker in ["COMI", "TMGH", "ABUK", "SWDY", "JUFO", "EAST", "EFID", "ORWE"]:
        tags.append("dividend")
    
    # Active/most traded (high volume)
    if volume > 1000000:
        tags.append("active")
    
    # Recently listed (after 2020)
    if listed and any(y in listed for y in ["2020", "2021", "2022", "2023", "2024", "2025", "2026"]):
        tags.append("recent")
    
    # Healthcare
    if "health" in sector or "hospital" in name or "pharma" in name or "medical" in name:
        tags.append("healthcare")
    
    # Metal funds
    if kind == "metal" or "metal" in sector or "gold" in sector or "silver" in sector:
        tags.append("metal")
    
    # Money market
    if "money market" in sector:
        tags.append("money-market")
    
    # Fixed income / bonds
    if "fixed income" in sector or "bond" in sector:
        tags.append("fixed-income")
    
    # Equity funds
    if kind == "fund" and ("equity" in sector or "growth" in sector):
        tags.append("equity")
    
    # Savings
    if "savings" in name or "saving" in sector:
        tags.append("savings")
    
    # Real estate
    if "real estate" in sector or "estate" in sector or "development" in sector or "housing" in name:
        tags.append("real-estate")
    
    # Balanced funds
    if "balanced" in sector or "balanced" in name:
        tags.append("balanced")
    
    return tags

# Apply tags
updated = 0
for inst in instruments:
    new_tags = get_tags(inst)
    if new_tags:
        inst["tags"] = new_tags
        updated += 1

# Save
guard = "<?php http_response_code(404); exit; ?>\n"
with open(INST_FILE, "w", encoding="utf-8") as f:
    f.write(guard + json.dumps(instruments, indent=4, ensure_ascii=False))

print(f"Added tags to {updated}/{len(instruments)} instruments")

# Print summary
from collections import Counter
all_tags = Counter()
for inst in instruments:
    for tag in inst.get("tags", []):
        all_tags[tag] += 1

print("\nTag distribution:")
for tag, count in all_tags.most_common():
    print(f"  {tag}: {count} instruments")
