// One place that knows how to push the detail screen and the order ticket,
// so every list that can open an instrument does it the same way.
import 'package:flutter/material.dart';
import '../core/money.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../screens/security.dart';
import '../screens/order.dart';

/// Opens instrument detail. [holding] adds the "My position" tab and lets the
/// ticket validate a sell against what is actually owned.
Future<void> openSecurity(
  BuildContext context, {
  required Api api,
  required Money money,
  required Instrument instrument,
  Holding? holding,
  num available = 0,
  VoidCallback? onChanged,
  String sessionState = 'Closed',
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SecurityScreen(
      instrument: instrument,
      money: money,
      api: api,
      holding: holding,
      logoUrl: api.logoUrl,
      sessionState: sessionState,
      onTrade: (side) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderScreen(
          api: api,
          instrument: instrument,
          money: money,
          side: side == 'buy' ? 'Buy' : 'Sell',
          holding: holding,
          available: available,
          logoUrl: api.logoUrl,
          onPlaced: onChanged,
        ),
      )),
    ),
  ));
}

/// Builds an Instrument from a Holding, for lists that only carry positions.
Instrument instrumentFromHolding(Holding h) => Instrument(
      ticker: h.ticker,
      name: h.name,
      last: h.price,
      change: h.change,
      sector: h.group == 'Metal funds' ? 'Gold' : h.group,
      kind: switch (h.group) {
        'Funds' || 'Metal funds' => 'fund',
        'Cash' => 'cash',
        _ => 'share',
      },
    );
