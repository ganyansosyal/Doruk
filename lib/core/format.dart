/// Eski web: current<0.01 ? 6 : current<1 ? 4 : current<100 ? 3 : 2
int priceDecimals(double p) => p < 0.01 ? 6 : p < 1 ? 4 : p < 100 ? 3 : 2;

String fmtPrice(double p) => '\$${p.toStringAsFixed(priceDecimals(p))}';

String fmtVol(double v) => v >= 1e9 ? '${(v / 1e9).toStringAsFixed(1)}B' : '${(v / 1e6).toStringAsFixed(0)}M';
