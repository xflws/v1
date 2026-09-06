#!/usr/bin/env python3
"""
TradingView EGX Full Data Scraper.
Uses Playwright (headless browser) to render TradingView and extract:
- Company logo (SVG)
- Sector
- Market cap
- EPS
- P/E ratio
- 52-week high/low
- Volume
- Previous close
- Day range
- Company description
- Website
- Employees
- Beta
- Dividend yield

Updates the backend instruments.json.php file with all scraped data.

Usage:
    pip install playwright aiohttp
    playwright install chromium
    python scripts/scrape_egx_full_data.py
"""

import asyncio
import os
import json
import re
from playwright.async_api import async_playwright

# All Egyptian EGX stocks
STOCKS = [
    "AALR", "ABUK", "ACAMD", "ACAP", "ACFR", "ACGC", "ACTF", "ADCI", "ADIB", "ADPC",
    "ADRI", "AFDI", "AFMC", "AIDC", "AIFI", "AIH", "AJWA", "ALCN", "ALEX", "ALUM",
    "ALXD", "AMER", "AMES", "AMIA", "AMII", "AMOC", "AMPI", "ANCC", "APPC", "APSW",
    "ARAB", "ARCC", "AREH", "ASCM", "ASPI", "ATLC", "ATQA", "AXPH", "BIDI", "BIGP",
    "BINV", "BIOC", "BONY", "BTFH", "CAED", "CANA", "CCAP", "CCRS", "CEFM", "CERA",
    "CFGH", "CICH", "CID", "CIEB", "CIRA", "CLHO", "CNFN", "COMI", "COPR", "COSG",
    "CPCI", "CPME", "CRST", "CSAG", "DAPH", "DCCC", "DCRC", "DEIN", "DGTZ", "DOMT",
    "DSCW", "DTPP", "EALR", "EASB", "EAST", "EBSC", "ECAP", "EDFM", "EEII", "EEP",
    "EFAC", "EFIC", "EFID", "EFIH", "EGAL", "EGAS", "EGBE", "EGCH", "EGOTH", "EGREF",
    "EGS220N1C016", "EGS30AJ1C016-EGP", "EGS370O1C013", "EGS385S1C012", "EGS3E071C013-EGP",
    "EGS48271C018-EGP", "EGS65101C015", "EGS65621C012", "EGS65861C014", "EGS659O1C015",
    "ELDL", "EMFD", "EKHO", "ESRS", "ETEL", "FAIT", "FAMY", "FARA", "FIDC", "FILC",
    "FKSR", "FMCI", "FMDI", "GBCO", "GBID", "GBRB", "GCGR", "GHMR", "GLZA", "GMDI",
    "GMMD", "GRAN", "GSK", "GSSE", "GTCS", "HELI", "HEPC", "HITI", "HMRD", "HDID",
    "HRHO", "HRSN", "HYDEV", "IBNS", "ICDH", "IDEC", "IGRD", "IHCO", "ISPH", "ITCC",
    "ISRA", "JUFO", "KBDI", "KHCB", "LBCS", "LION", "LMTL", "MCPH", "MCDR", "MDRN",
    "MEGC", "MFPC", "MHC", "MIDF", "MICO", "MIET", "MINA", "MNGT", "MNHD", "MOH",
    "MPHC", "MRNA", "MSTD", "MTEL", "NADE", "NAHO", "NBE", "NBAD", "NDEC", "NEFT",
    "NEZE", "NILE", "NPHO", "NSGB", "NYCA", "OCDI", "OCTF", "OILS", "OLFI", "OPDC",
    "ORAS", "ORWE", "OSIM", "OULC", "OZDI", "PARK", "PCHE", "PHDC", "PHIN", "PIFI",
    "PILT", "PLAC", "PLUS", "POLN", "POSH", "PRVT", "PSAP", "PSAM", "QALY", "QAYA",
    "QCAP", "QMAT", "QMCI", "QNBE", "QNBC", "QOKA", "QTEL", "QUAC", "QULA", "RAZI",
    "RECU", "REGI", "REMC", "RENO", "RICE", "RISE", "RMCC", "RMC", "ROFM", "RSLS",
    "SADAT", "SAGS", "SAIC", "SAPN", "SARK", "SAUD", "SBID", "SCDH", "SCDP", "SEPC",
    "SFID", "SHDR", "SHGP", "SHMS", "SIDE", "SIGD", "SILO", "SKPC", "SLAE", "SLCG",
    "SLHO", "SMFG", "SNID", "SPED", "SPIN", "SSIF", "STAA", "SUGR", "SUMA", "SUZC",
    "SWDY", "SWIF", "TALC", "TALI", "TBCO", "TECO", "TELM", "THDI", "THVR", "TIDC",
    "TIGR", "TIMC", "TLGH", "TMRG", "TMGH", "TORE", "TPAC", "TREL", "TRIP", "TSIL",
    "TSME", "TTFA", "UHID", "UNIP", "UPFD", "USIP", "USPH", "UWAY", "VAKA", "VALE",
    "VENI", "VERO", "WADI", "WECH", "WICA", "WILM", "WORA", "YELI", "ZEIS", "ZOMR",
    "ZOOM", "GLD", "SLVR", "AZEQ", "XFIX", "AZSH", "AZMM", "AZFX",
]

# Paths
BACKEND_DIR = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted"
INSTRUMENTS_FILE = os.path.join(BACKEND_DIR, "api", "data", "live", "instruments.json.php")
LOGO_DIR = os.path.join(BACKEND_DIR, "api", "files")
OUTPUT_DIR = "scraper-output"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(LOGO_DIR, exist_ok=True)

def parse_number(s):
    """Parse a number string like '141.00', '3.1 M', '−1.31%' into a float."""
    if not s:
        return None
    s = s.strip().replace(',', '')
    # Handle M (millions) and K (thousands)
    if s.endswith('M'):
        return float(s[:-1]) * 1_000_000
    elif s.endswith('K'):
        return float(s[:-1]) * 1_000
    elif s.endswith('%'):
        return float(s[:-1].replace('−', '-'))
    else:
        try:
            return float(s.replace('−', '-'))
        except:
            return None

def parse_change(s):
    """Parse change like '+1.45%' or '−1.31%' into float."""
    if not s:
        return 0.0
    s = s.strip().replace('%', '').replace('−', '-')
    try:
        return float(s)
    except:
        return 0.0

async def scrape_stock_data(page, ticker):
    """Navigate to TradingView symbol page and extract all data."""
    url = f"https://www.tradingview.com/symbols/EGX-{ticker}/"
    
    result = {
        "ticker": ticker,
        "name": "",
        "sector": "",
        "industry": "",
        "last": 0.0,
        "change": 0.0,
        "volume": 0,
        "market_cap": None,
        "eps": None,
        "pe_ratio": None,
        "week52_high": None,
        "week52_low": None,
        "prev_close": None,
        "day_high": None,
        "day_low": None,
        "description": "",
        "website": "",
        "employees": None,
        "beta": None,
        "dividend_yield": None,
        "ceo": "",
        "headquarters": "",
        "founded": "",
        "ipo_date": "",
        "isin": "",
        "logo_url": None,
    }
    
    try:
        await page.goto(url, wait_until="networkidle", timeout=15000)
        await page.wait_for_timeout(2000)  # Let JS finish rendering
        
        # Extract company name
        name = await page.evaluate("""
            () => {
                const h1 = document.querySelector('h1');
                if (h1) return h1.textContent.trim().split(' — ')[0].trim();
                const title = document.querySelector('title');
                if (title) return title.textContent.split('—')[0].trim();
                return '';
            }
        """)
        result["name"] = name or ticker
        
        # Extract sector
        sector = await page.evaluate("""
            () => {
                // Look for sector in the overview section
                const labels = document.querySelectorAll('[class*="label"]');
                for (const label of labels) {
                    if (label.textContent.trim().toLowerCase() === 'sector') {
                        const value = label.nextElementSibling;
                        if (value) return value.textContent.trim();
                    }
                }
                return '';
            }
        """)
        result["sector"] = sector or ""
        
        # Extract price and change
        price_data = await page.evaluate("""
            () => {
                // Look for the main price display
                const priceEl = document.querySelector('[class*="price"], [class*="last"]');
                const price = priceEl ? priceEl.textContent.trim() : '';
                
                // Look for change percentage
                const changeEl = document.querySelector('[class*="change"], [class*="percent"]');
                const change = changeEl ? changeEl.textContent.trim() : '';
                
                return { price, change };
            }
        """)
        
        if price_data.get("price"):
            result["last"] = parse_number(price_data["price"]) or 0.0
        if price_data.get("change"):
            result["change"] = parse_change(price_data["change"])
        
        # Extract overview stats (TradingView renders these in a description panel)
        stats = await page.evaluate("""
            () => {
                const stats = {};
                // TradingView renders stats in a grid with labels and values
                const labels = document.querySelectorAll('[class*="labelCell"], [class*="label"]');
                for (const label of labels) {
                    const text = label.textContent.trim().toLowerCase();
                    const valueEl = label.closest('tr')?.querySelector('td:last-child') 
                        || label.nextElementSibling 
                        || label.parentElement?.nextElementSibling?.querySelector('[class*="value"]');
                    if (valueEl) {
                        const val = valueEl.textContent.trim();
                        if (val && val !== '—') {
                            stats[text] = val;
                        }
                    }
                }
                
                // Also look for the company description panel
                const desc = document.querySelector('[class*="description"], [class*="about"]');
                if (desc) stats['description'] = desc.textContent.trim();
                
                // Look for CEO, headquarters, founded, IPO, ISIN in the company info
                const companyInfo = document.querySelectorAll('[class*="company"], [class*="profile"]');
                for (const section of companyInfo) {
                    const rows = section.querySelectorAll('div, tr, li');
                    for (const row of rows) {
                        const label = row.querySelector('[class*="label"]');
                        const value = row.querySelector('[class*="value"]');
                        if (label && value) {
                            stats[label.textContent.trim().toLowerCase()] = value.textContent.trim();
                        }
                    }
                }
                
                return stats;
            }
        """)
        
        # Map stats to result
        stat_mapping = {
            "market cap": "market_cap",
            "eps": "eps",
            "p/e ratio": "pe_ratio",
            "52 week high": "week52_high",
            "52 week low": "week52_low",
            "prev. close": "prev_close",
            "previous close": "prev_close",
            "day range": "day_range",
            "high": "day_high",
            "low": "day_low",
            "volume": "volume",
            "employees": "employees",
            "beta": "beta",
            "dividend yield": "dividend_yield",
            "dividend yield %": "dividend_yield",
            "sector": "sector",
            "industry": "industry",
            "website": "website",
            "description": "description",
            "ceo": "ceo",
            "headquarters": "headquarters",
            "founded": "founded",
            "ipo date": "ipo_date",
            "isin": "isin",
        }
        
        for key, field in stat_mapping.items():
            if key in stats:
                if field in ["market_cap", "eps", "pe_ratio", "week52_high", "week52_low", 
                             "prev_close", "day_high", "day_low", "volume", "employees", 
                             "beta", "dividend_yield"]:
                    result[field] = parse_number(stats[key])
                else:
                    result[field] = stats[key]
        
        # Extract logo URL
        logo_url = await page.evaluate("""
            () => {
                // Look for og:image meta tag
                const ogImage = document.querySelector('meta[property="og:image"]');
                if (ogImage) return ogImage.content;
                
                // Look for any img with tradingview logo
                const imgs = document.querySelectorAll('img');
                for (const img of imgs) {
                    const src = img.src || '';
                    if (src.includes('s3-symbol-logo')) {
                        return src;
                    }
                }
                return '';
            }
        """)
        result["logo_url"] = logo_url or None
        
        # Extract description
        description = await page.evaluate("""
            () => {
                const desc = document.querySelector('[class*="description"], [class*="about"]');
                return desc ? desc.textContent.trim() : '';
            }
        """)
        result["description"] = description or ""
        
        return result
        
    except Exception as e:
        print(f"  ✗ Error scraping {ticker}: {str(e)}")
        result["error"] = str(e)
        return result

async def download_logo(ticker, logo_url):
    """Download logo from TradingView CDN."""
    if not logo_url:
        return False
    
    import aiohttp
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(logo_url, timeout=10) as resp:
                if resp.status == 200:
                    content = await resp.read()
                    if len(content) > 100:
                        ext = "svg" if "svg" in logo_url else "png"
                        filepath = os.path.join(LOGO_DIR, f"{ticker}.{ext}")
                        with open(filepath, "wb") as f:
                            f.write(content)
                        return True
        except:
            pass
    return False

def load_existing_instruments():
    """Load existing instruments.json.php."""
    if os.path.exists(INSTRUMENTS_FILE):
        with open(INSTRUMENTS_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        # Skip PHP guard line
        if content.startswith("<?php"):
            json_start = content.index("\n") + 1
            data = json.loads(content[json_start:])
        else:
            data = json.loads(content)
        return data
    return []

def save_instruments(instruments):
    """Save instruments.json.php with PHP guard line."""
    guard = "<?php http_response_code(404); exit; ?>\n"
    with open(INSTRUMENTS_FILE, "w", encoding="utf-8") as f:
        f.write(guard + json.dumps(instruments, indent=4, ensure_ascii=False))

def merge_scraped_data(existing, scraped):
    """Merge scraped data into existing instruments."""
    for stock in scraped:
        if "error" in stock:
            continue
        
        ticker = stock["ticker"]
        
        # Find existing instrument
        found = False
        for inst in existing:
            if inst.get("ticker") == ticker:
                found = True
                # Update with scraped data
                if stock.get("name") and stock["name"] != ticker:
                    inst["name"] = stock["name"]
                if stock.get("sector"):
                    inst["sector"] = stock["sector"]
                if stock.get("last"):
                    inst["last"] = stock["last"]
                if stock.get("change") is not None:
                    inst["change"] = stock["change"]
                if stock.get("volume"):
                    inst["volume"] = stock["volume"]
                if stock.get("prev_close"):
                    inst["prev"] = stock["prev_close"]
                break
        
        if not found:
            # Create new instrument
            new_inst = {
                "ticker": ticker,
                "name": stock.get("name", ticker),
                "nameAr": "",
                "kind": "share",
                "sector": stock.get("sector", ""),
                "last": stock.get("last", 0.0),
                "change": stock.get("change", 0.0),
                "prev": stock.get("prev_close", stock.get("last", 0.0)),
                "state": "trading",
                "currency": "EGP",
                "lotSize": 1,
                "minOrder": 0,
                "tradesIn": "units",
                "kycTier": 1,
            }
            existing.append(new_inst)
    
    return existing

async def main():
    print(f"{'='*60}")
    print(f"TradingView EGX Full Data Scraper")
    print(f"{'='*60}")
    print(f"Scraping {len(STOCKS)} stocks...")
    print(f"Output: {os.path.abspath(OUTPUT_DIR)}")
    print(f"Backend: {BACKEND_DIR}")
    print(f"{'='*60}\n")
    
    all_results = []
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        page = await context.new_page()
        
        for i, ticker in enumerate(STOCKS):
            print(f"[{i+1}/{len(STOCKS)}] {ticker}...")
            
            result = await scrape_stock_data(page, ticker)
            all_results.append(result)
            
            # Download logo if found
            if result.get("logo_url"):
                logo_success = await download_logo(ticker, result["logo_url"])
                if logo_success:
                    print(f"  ✓ Logo downloaded")
                else:
                    print(f"  ✗ Logo download failed")
            
            # Print summary
            print(f"  Name: {result.get('name', 'N/A')}")
            print(f"  Price: {result.get('last', 0):.2f} | Change: {result.get('change', 0):.2f}%")
            print(f"  Sector: {result.get('sector', 'N/A')}")
            print(f"  Industry: {result.get('industry', 'N/A')}")
            if result.get('ceo'): print(f"  CEO: {result['ceo']}")
            if result.get('headquarters'): print(f"  HQ: {result['headquarters']}")
            if result.get('website'): print(f"  Web: {result['website']}")
            if result.get('founded'): print(f"  Founded: {result['founded']}")
            if result.get('isin'): print(f"  ISIN: {result['isin']}")
            print()
            
            await page.wait_for_timeout(1500)  # Rate limiting
        
        await browser.close()
    
    # Save scraped data to JSON
    output_file = os.path.join(OUTPUT_DIR, "scraped_data.json")
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)
    print(f"\nScraped data saved to: {output_file}")
    
    # Merge with existing instruments
    existing = load_existing_instruments()
    merged = merge_scraped_data(existing, all_results)
    save_instruments(merged)
    print(f"Backend instruments updated: {INSTRUMENTS_FILE}")
    print(f"Total instruments: {len(merged)}")
    
    # Summary
    logos_downloaded = sum(1 for r in all_results if r.get("logo_url"))
    sectors_found = sum(1 for r in all_results if r.get("sector"))
    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")
    print(f"Stocks scraped: {len(all_results)}")
    print(f"Logos found: {logos_downloaded}")
    print(f"Sectors found: {sectors_found}")
    print(f"Instruments updated: {len(merged)}")
    print(f"{'='*60}")

if __name__ == "__main__":
    asyncio.run(main())
