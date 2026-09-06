#!/usr/bin/env python3
"""
Full-fledged TradingView Egyptian Stock Logo Scraper.
Uses Playwright (headless browser) to render JavaScript and extract logo URLs.
Downloads all logos to a local folder.

Usage:
    pip install playwright
    playwright install chromium
    python fetch_egx_logos_full.py
"""

import asyncio
import os
import json
from playwright.async_api import async_playwright

# All Egyptian EGX stocks (280+ tickers from the screener)
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
    "ELDL", "EMFD", "EKHO", "ESRS", "ETEL", "ETEL", "EFID", "FAIT", "FAMY", "FARA",
    "FIDC", "FILC", "FKSR", "FMCI", "FMDI", "GBCO", "GBID", "GBRB", "GCGR", "GHMR",
    "GLZA", "GMDI", "GMMD", "GRAN", "GSK", "GSSE", "GTCS", "HELI", "HEPC", "HITI",
    "HMRD", "HDID", "HRHO", "HRSN", "HYDEV", "IBNS", "ICDH", "IDEC", "IGRD", "IHCO",
    "ISPH", "ITCC", "ISRA", "JUFO", "KBDI", "KHCB", "LBCS", "LION", "LMTL", "MCPH",
    "MCDR", "MDRN", "MEGC", "MFPC", "MHC", "MIDF", "MICO", "MIET", "MINA", "MNGT",
    "MNHD", "MOH", "MPHC", "MRNA", "MSTD", "MTEL", "NADE", "NAHO", "NBE", "NBAD",
    "NDEC", "NEFT", "NEZE", "NILE", "NPHO", "NSGB", "NYCA", "OCDI", "OCTF", "OILS",
    "OLFI", "OPDC", "ORAS", "ORWE", "OSIM", "OULC", "OZDI", "PARK", "PCHE", "PHDC",
    "PHIN", "PIFI", "PILT", "PLAC", "PLUS", "POLN", "POSH", "PRVT", "PSAP", "PSAM",
    "QALY", "QAYA", "QCAP", "QMAT", "QMCI", "QNBE", "QNBC", "QOKA", "QTEL", "QUAC",
    "QULA", "RAZI", "RECU", "REGI", "REMC", "RENO", "RICE", "RISE", "RMCC", "RMC",
    "ROFM", "RSLS", "SADAT", "SAGS", "SAIC", "SAPN", "SARK", "SAUD", "SBID", "SCDH",
    "SCDP", "SEPC", "SFID", "SHDR", "SHGP", "SHMS", "SIDE", "SIGD", "SILO", "SKPC",
    "SLAE", "SLCG", "SLHO", "SMFG", "SNID", "SPED", "SPIN", "SSIF", "STAA", "SUGR",
    "SUMA", "SUZC", "SWDY", "SWIF", "TALC", "TALI", "TBCO", "TECO", "TELM", "THDI",
    "THVR", "TIDC", "TIGR", "TIMC", "TLGH", "TMRG", "TMGH", "TORE", "TPAC", "TREL",
    "TRIP", "TSIL", "TSME", "TTFA", "UHID", "UNIP", "UPFD", "USIP", "USPH", "UWAY",
    "VAKA", "VALE", "VENI", "VERO", "WADI", "WECH", "WICA", "WILM", "WORA", "YELI",
    "ZEIS", "ZOMR", "ZOOM", "GLD", "SLVR", "AZEQ", "XFIX", "AZSH", "AZMM", "AZFX",
]

# Company name to slug mapping (manually curated for accuracy)
COMPANY_SLUGS = {
    "COMI": "commercial-international-bank-egypt",
    "TMGH": "talaat-moustafa-group-holding",
    "ETEL": "telecom-egypt",
    "SWDY": "elsewedy-electric",
    "CLHO": "cleopatra-hospital-company",
    "CPME": "catalyst-partners-middle-east",
    "CCAP": "qala-for-financial-investments",
    "ACGC": "arab-cotton-ginning",
    "AMES": "alexandria-new-medical-center",
    "ABUK": "abou-kir-fertilizers-chemicals-industries",
    "GLD": "gold",
    "AZEQ": "azimut-equity-fund",
    "XFIX": "xflws-fixed-income",
    "AFMC": "alexandria-flour-mills",
    "GGCC": "giza-general-contracting",
    "JUFO": "juhayna-food-industries",
    "GSK": "glaxosmithkline",
    "ORWE": "arabian-pharmaceuticals",
    "SKPC": "sidi-kerir-petrochemicals",
    "DSCW": "dice-sports-casual-wear",
    "ELSH": "el-shams-housing",
    "INEG": "international-engineering",
    "ACAP": "a-capital-holding",
    "EFIH": "e-finance-for-digital-financial-investments",
    "EGAL": "egypt-aluminum",
    "CICH": "ci-capital-holding",
    "EGCH": "egyptian-chemical-industries",
    "EGAS": "egypt-gas",
    "PHDC": "palm-hills-developments",
    "HRHO": "horizon-holding",
    "OILS": "egyptian-oil-gas",
    "ESRS": "elswedy-ict",
}

OUTPUT_DIR = "egx-logos"
os.makedirs(OUTPUT_DIR, exist_ok=True)

async def get_logo_url(page, ticker):
    """Navigate to TradingView symbol page and extract logo URL."""
    url = f"https://www.tradingview.com/symbols/EGX-{ticker}/"
    
    try:
        await page.goto(url, wait_until="networkidle", timeout=15000)
        await page.wait_for_timeout(2000)  # Let JS finish rendering
        
        # Try to find the logo image in the rendered page
        logo_src = await page.evaluate("""
            () => {
                // Look for the company logo in the header
                const logos = document.querySelectorAll('img[alt*="logo"], img[src*="logo"], img[src*="symbol"]');
                for (const img of logos) {
                    const src = img.src || '';
                    if (src.includes('s3-symbol-logo') || src.includes('tradingview.com')) {
                        return src;
                    }
                }
                
                // Look for og:image meta tag
                const ogImage = document.querySelector('meta[property="og:image"]');
                if (ogImage) return ogImage.content;
                
                // Look for any SVG in the header area
                const headerSvgs = document.querySelectorAll('header svg, .symbol-logo svg');
                if (headerSvgs.length > 0) {
                    return 'svg-found';
                }
                
                return null;
            }
        """)
        
        return logo_src
    except Exception as e:
        return f"Error: {str(e)}"

async def download_logo(session, url, ticker):
    """Download the logo to the output directory."""
    try:
        async with session.get(url) as resp:
            if resp.status == 200:
                content = await resp.read()
                if len(content) > 100:
                    ext = "svg" if "svg" in url else "png"
                    filepath = os.path.join(OUTPUT_DIR, f"{ticker}.{ext}")
                    with open(filepath, "wb") as f:
                        f.write(content)
                    return True
    except:
        pass
    return False

async def main():
    import aiohttp
    
    print(f"Fetching logos for {len(STOCKS)} Egyptian stocks...\n")
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        page = await context.new_page()
        
        results = []
        
        for i, ticker in enumerate(STOCKS):
            print(f"[{i+1}/{len(STOCKS)}] {ticker}...")
            
            logo_url = await get_logo_url(page, ticker)
            
            if logo_url and "Error" not in str(logo_url):
                print(f"  ✓ Found: {logo_url[:80]}...")
                results.append((ticker, "OK", logo_url))
            else:
                print(f"  ✗ {logo_url}")
                results.append((ticker, "Not found", ""))
            
            await page.wait_for_timeout(1000)  # Rate limiting
        
        await browser.close()
    
    # Download all logos
    print(f"\n{'='*50}")
    print("Downloading logos...")
    print(f"{'='*50}\n")
    
    async with aiohttp.ClientSession() as session:
        for ticker, status, url in results:
            if status == "OK" and url:
                success = await download_logo(session, url, ticker)
                if success:
                    print(f"  ✓ Downloaded {ticker}")
                else:
                    print(f"  ✗ Failed to download {ticker}")
    
    # Summary
    ok = sum(1 for _, s, _ in results if s == "OK")
    print(f"\n{'='*50}")
    print(f"SUMMARY: {ok}/{len(STOCKS)} logos found")
    print(f"{'='*50}")
    print(f"\nFiles saved to: {os.path.abspath(OUTPUT_DIR)}")
    
    # Save mapping
    mapping = {ticker: f"{ticker}.{('svg' if url.endswith('.svg') else 'png')}" 
               for ticker, status, url in results if status == "OK"}
    with open(os.path.join(OUTPUT_DIR, "logo_mapping.json"), "w") as f:
        json.dump(mapping, f, indent=2)
    print(f"Mapping saved to: logo_mapping.json")

if __name__ == "__main__":
    asyncio.run(main())
