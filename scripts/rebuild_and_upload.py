#!/usr/bin/env python3
"""
Upload all logos to server + rebuild instruments with Yahoo Finance prices.
"""
import os
import json
import requests
import time

FTP_USER = "xflws-qwen-xerp@xflws.com"
FTP_PASS = "xflws@4556"
SERVER = "xflws.com"
LOGO_DIR = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\files"
SCRAPED = r"c:\xflws\scripts\scraper-output\scraped_data.json"

# Load scraped data
with open(SCRAPED, encoding="utf-8") as f:
    scraped = json.load(f)
scraped_map = {s["ticker"]: s for s in scraped}

print(f"Loaded {len(scraped_map)} stocks from scraped data")

# Build new instruments list with Yahoo Finance prices
instruments = []
for ticker, s in scraped_map.items():
    inst = {
        "ticker": ticker,
        "name": s.get("name", ticker),
        "nameAr": "",
        "kind": "share",
        "sector": s.get("sector", ""),
        "industry": s.get("industry", ""),
        "last": 0.0,
        "change": 0.0,
        "prev": 0.0,
        "state": "trading",
        "currency": "EGP",
        "lotSize": 1,
        "minOrder": 0,
        "tradesIn": "units",
        "kycTier": 1,
        "website": s.get("website", ""),
        "ceo": s.get("ceo", ""),
        "headquarters": s.get("headquarters", ""),
        "founded": s.get("founded", ""),
        "ipoDate": s.get("ipo_date", ""),
        "isin": s.get("isin", ""),
        "description": s.get("description", ""),
        "volume": 0,
        "turnover": 0,
    }
    instruments.append(inst)

# Try to fetch Yahoo Finance prices for major stocks
print("Fetching Yahoo Finance prices for major stocks...")
yahoo_tickers = ["COMI", "TMGH", "ETEL", "SWDY", "CLHO", "CCAP", "CPME", "ACGC", "AMES", "ABUK", "JUFO", "GSK", "ORWE", "SKPC", "AFMC", "ELSH", "HRHO", "INEG"]

for ticker in yahoo_tickers:
    try:
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}.CA?interval=1d&range=1d"
        resp = requests.get(url, headers={"User-Agent": "Mozilla/5.0"}, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            meta = data.get("chart", {}).get("result", [{}])[0].get("meta", {})
            price = meta.get("regularMarketPrice", 0)
            prev = meta.get("chartPreviousClose", meta.get("previousClose", 0))
            change = meta.get("regularMarketChangePercent", 0)
            if price > 0:
                for inst in instruments:
                    if inst["ticker"] == ticker:
                        inst["last"] = round(price, 2)
                        inst["prev"] = round(prev, 2)
                        inst["change"] = round(change, 2)
                        print(f"  {ticker}: {price} EGP ({change:+.2f}%)")
                        break
        time.sleep(0.5)
    except Exception as e:
        print(f"  {ticker}: failed ({e})")

# Save new instruments file
INST_FILE = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\data\live\instruments.json.php"
guard = "<?php http_response_code(404); exit; ?>\n"
with open(INST_FILE, "w", encoding="utf-8") as f:
    f.write(guard + json.dumps(instruments, indent=4, ensure_ascii=False))
print(f"\nSaved {len(instruments)} instruments to instruments.json.php")

# Upload logos via FTP
print("\nUploading logos to server...")
from ftplib import FTP
ftp = FTP(SERVER)
ftp.login(FTP_USER, FTP_PASS)
ftp.cwd("api/files")

uploaded = 0
files = [f for f in os.listdir(LOGO_DIR) if f.endswith((".png", ".svg", ".jpg"))]
for i, fname in enumerate(files):
    filepath = os.path.join(LOGO_DIR, fname)
    with open(filepath, "rb") as f:
        try:
            ftp.storbinary(f"STOR {fname}", f)
            uploaded += 1
            if (i + 1) % 50 == 0:
                print(f"  Uploaded {i+1}/{len(files)} logos...")
        except Exception as e:
            print(f"  Failed {fname}: {e}")
    time.sleep(0.05)

ftp.quit()
print(f"\nUploaded {uploaded}/{len(files)} logos to server")

# Upload instruments file
print("\nUploading instruments.json.php...")
ftp = FTP(SERVER)
ftp.login(FTP_USER, FTP_PASS)
ftp.cwd("api/data/live")
with open(INST_FILE, "rb") as f:
    ftp.storbinary("STOR instruments.json.php", f)
ftp.quit()
print("Instruments uploaded")

print("\nDone! Server now has:")
print(f"  - {len(instruments)} instruments with real data")
print(f"  - {uploaded} logos")
print(f"  - Yahoo Finance prices for major stocks")
