// Filtered instrument list — a proper browsing screen for a category of
// instruments (funds by type, stocks by sector, metals, etc.).
//
// Maintains the shell's header and bottom tab bar by being rendered inside
// the Shell rather than pushed as a new route.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/atoms.dart';
import '../widgets/holdings.dart' show tickerColour;
import '../widgets/open_security.dart';

/// The filter categories available.
enum InstrumentFilter {
  allStocks('Egyptian shares', 'All companies on the exchange'),
  healthcare('Health care', 'Healthcare companies on the EGX'),
  localFunds('Local currency funds', 'EGP-denominated mutual funds'),
  foreignFunds('Foreign currency funds', 'USD and EUR funds'),
  metalFunds('Metal funds', 'Gold, silver and commodity exposure'),
  shariaFunds('Sharia-compliant', 'Funds compliant with Islamic finance'),
  moneyMarket('Money market', 'Daily-return cash instruments'),
  fixedIncome('Fixed income', 'Bond and treasury funds'),
  equityFunds('Equity funds', 'Stock-market index and active funds'),
  savings('Savings', 'Low-risk daily-return instruments'),
  metals('Metals', 'Gold and silver by the gram'),
  dividend('Dividend payers', 'Funds focused on distributions'),
  realEstate('Real estate', 'Property-linked instruments'),
  balanced('Balanced', 'Mixed asset allocation funds'),
  egx30('EGX30 companies', 'The 30 largest companies on the exchange'),
  recentlyListed('Recently listed', 'New arrivals to the exchange'),
  mostTraded('Most traded', 'Highest volume instruments today'),
  bySector('Sector', 'Companies in this sector');

  const InstrumentFilter(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

/// Optional sector override for bySector filter.
String? sectorFilterName;

/// Matches an instrument to a filter category. Public so Discover can count.
bool matchesFilter(Instrument i, InstrumentFilter f) {
  switch (f) {
    case InstrumentFilter.allStocks:
      return i.kind == 'share';
    case InstrumentFilter.healthcare:
      return i.kind == 'share' &&
          i.sector.toLowerCase().contains('health');
    case InstrumentFilter.localFunds:
      return i.kind == 'fund' && i.currency == 'EGP';
    case InstrumentFilter.foreignFunds:
      return i.kind == 'fund' && i.currency != 'EGP';
    case InstrumentFilter.metalFunds:
      return i.kind == 'metal' ||
          (i.kind == 'fund' &&
              (i.sector.toLowerCase().contains('metal') ||
                  i.sector.toLowerCase().contains('gold')));
    case InstrumentFilter.shariaFunds:
      return i.sector.toLowerCase().contains('sharia');
    case InstrumentFilter.moneyMarket:
      return i.sector.toLowerCase().contains('money market');
    case InstrumentFilter.fixedIncome:
      return i.sector.toLowerCase().contains('fixed income') ||
          i.sector.toLowerCase().contains('bond');
    case InstrumentFilter.equityFunds:
      return i.kind == 'fund' && i.sector.toLowerCase().contains('equity');
    case InstrumentFilter.savings:
      return i.sector.toLowerCase().contains('money market') ||
          i.sector.toLowerCase().contains('fixed income');
    case InstrumentFilter.metals:
      return i.kind == 'metal';
    case InstrumentFilter.dividend:
      return i.sector.toLowerCase().contains('dividend');
    case InstrumentFilter.realEstate:
      return i.sector.toLowerCase().contains('real estate');
    case InstrumentFilter.balanced:
      return i.sector.toLowerCase().contains('balanced');
    case InstrumentFilter.egx30:
      return i.index.isNotEmpty;
    case InstrumentFilter.recentlyListed:
      return i.listed.isNotEmpty;
    case InstrumentFilter.mostTraded:
      return i.kind == 'share' && i.volume > 0;
    case InstrumentFilter.bySector:
      return sectorFilterName != null &&
          i.sector.toLowerCase() == sectorFilterName!.toLowerCase();
  }
}

class InstrumentListScreen extends StatefulWidget {
  const InstrumentListScreen({
    super.key,
    required this.filter,
    required this.api,
    required this.money,
    this.available = 0,
    this.logoUrl,
    this.onBack,
  });

  final InstrumentFilter filter;
  final Api api;
  final Money money;
  final num available;
  final String Function(String ticker)? logoUrl;
  final VoidCallback? onBack;

  @override
  State<InstrumentListScreen> createState() => _InstrumentListScreenState();
}

class _InstrumentListScreenState extends State<InstrumentListScreen> {
  List<Instrument> _all = const [];
  bool _loading = true;
  String _sort = 'name'; // name | change | value

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.instruments();
      if (mounted) {
        setState(() {
          _all = rows
              .whereType<Map>()
              .map((e) => Instrument.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Instrument> get _filtered {
    final rows = _all.where((i) => matchesFilter(i, widget.filter)).toList();
    switch (_sort) {
      case 'change':
        rows.sort((a, b) => b.change.compareTo(a.change));
      case 'value':
        rows.sort((a, b) => b.last.compareTo(a.last));
      default:
        rows.sort((a, b) => a.name.compareTo(b.name));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final rows = _filtered;

    return Container(
      color: pal.p0,
      child: Column(
        children: [
          // Header with back button and title
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack ??
                        () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal.p1,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Ph.caretLeft, size: 15, color: pal.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            widget.filter == InstrumentFilter.bySector &&
                                    sectorFilterName != null
                                ? sectorFilterName!
                                : widget.filter.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: pal.ink,
                            )),
                        Text(widget.filter.subtitle,
                            style:
                                TextStyle(fontSize: 11.5, color: pal.mute)),
                      ],
                    ),
                  ),
                  // Sort toggle
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _sort = switch (_sort) {
                          'name' => 'change',
                          'change' => 'value',
                          _ => 'name',
                        };
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: pal.p1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Ph.arrowsDownUp, size: 12, color: pal.mute),
                          const SizedBox(width: 4),
                          Text(
                              _sort == 'name'
                                  ? 'Name'
                                  : _sort == 'change'
                                      ? 'Move'
                                      : 'Price',
                              style: TextStyle(
                                  fontSize: 11, color: pal.mute)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${rows.length} instruments',
                  style: TextStyle(fontSize: 11.5, color: pal.mute)),
            ),
          ),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? EmptyState(
                        icon: Ph.chartBar,
                        title: 'Nothing here yet',
                        body:
                            'No instruments match this category right now.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final inst = rows[i];
                          return InkWell(
                            onTap: () => openSecurity(
                              context,
                              api: widget.api,
                              money: widget.money,
                              instrument: inst,
                              available: widget.available,
                            ),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: pal.line),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Mark(
                                    monogram: inst.ticker
                                        .substring(
                                            0,
                                            inst.ticker.length
                                                .clamp(0, 2)),
                                    colour: tickerColour(inst.ticker),
                                    ticker: inst.ticker,
                                    size: 40,
                                    logoUrl: widget.logoUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(inst.name,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: pal.ink,
                                            )),
                                        Text(
                                            '${inst.ticker} · ${inst.sector}${inst.currency != 'EGP' ? ' · ${inst.currency}' : ''}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: pal.mute)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        widget.money.format(inst.last,
                                            decimals: 2),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                      PctTag(
                                          delta: inst.change,
                                          up: inst.up),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
