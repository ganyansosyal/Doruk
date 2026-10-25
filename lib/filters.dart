class FilterItem {
  final String name;
  final List<double> matrix;
  const FilterItem(this.name, this.matrix);
}

List<double> _sat(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrast(double c) {
  final o = 128 * (1 - c);
  return [
    c, 0, 0, 0, o,
    0, c, 0, 0, o,
    0, 0, c, 0, o,
    0, 0, 0, 1, 0,
  ];
}

List<double> _bright(double o) => [
      1, 0, 0, 0, o,
      0, 1, 0, 0, o,
      0, 0, 1, 0, o,
      0, 0, 0, 1, 0,
    ];

List<double> _tint(double r, double g, double b) => [
      r, 0, 0, 0, 0,
      0, g, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0,
    ];

List<double> _mul(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[i * 5 + k] * b[k * 5 + j];
      }
      if (j == 4) v += a[i * 5 + 4];
      out[i * 5 + j] = v;
    }
  }
  return out;
}

FilterItem _f(String name, List<List<double>> steps) {
  var m = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];
  for (final s in steps) {
    m = _mul(s, m);
  }
  return FilterItem(name, m);
}

final List<FilterItem> photoFilters = [
  const FilterItem('Orijinal', [
    1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,
  ]),
  _f('Clarendon', [_sat(1.3), _contrast(1.2), _tint(0.95, 1.0, 1.08)]),
  _f('Gingham', [_sat(0.8), _contrast(0.9), _bright(20), _tint(1.0, 0.98, 0.95)]),
  _f('Moon', [_sat(0), _contrast(1.1), _bright(10)]),
  _f('Lark', [_sat(1.2), _bright(18), _tint(0.98, 1.05, 1.05)]),
  _f('Reyes', [_sat(0.75), _contrast(0.9), _bright(30), _tint(1.05, 1.02, 0.95)]),
  _f('Juno', [_sat(1.35), _contrast(1.1), _tint(1.08, 1.0, 0.9)]),
  _f('Slumber', [_sat(0.7), _contrast(0.95), _bright(-5), _tint(1.05, 0.98, 0.92)]),
  _f('Crema', [_sat(0.8), _contrast(0.95), _bright(10), _tint(1.04, 1.0, 0.94)]),
  _f('Ludwig', [_sat(1.1), _contrast(1.1), _tint(1.03, 1.0, 0.97)]),
  _f('Aden', [_sat(0.85), _bright(15), _tint(1.08, 0.97, 1.04)]),
  _f('Perpetua', [_sat(1.1), _bright(10), _tint(0.95, 1.05, 1.0)]),
  _f('Mayfair', [_sat(1.15), _contrast(1.1), _tint(1.08, 1.0, 0.97)]),
  _f('Rise', [_sat(0.9), _contrast(0.92), _bright(25), _tint(1.08, 1.02, 0.92)]),
  _f('Hudson', [_sat(1.1), _contrast(1.2), _tint(0.92, 1.0, 1.12)]),
  _f('Valencia', [_sat(1.1), _contrast(0.95), _bright(12), _tint(1.08, 1.02, 0.9)]),
  _f('X-Pro II', [_sat(1.3), _contrast(1.35), _tint(1.05, 0.98, 0.9)]),
  _f('Sierra', [_sat(0.85), _contrast(0.9), _bright(18), _tint(1.05, 1.0, 0.95)]),
  _f('Willow', [_sat(0.2), _contrast(0.95), _bright(10), _tint(1.02, 1.0, 1.04)]),
  _f('Lo-Fi', [_sat(1.4), _contrast(1.4)]),
  _f('Earlybird', [_sat(0.9), _contrast(1.05), _bright(8), _tint(1.1, 1.0, 0.8)]),
  _f('Brannan', [_sat(0.8), _contrast(1.3), _tint(1.05, 1.02, 0.9)]),
  _f('Inkwell', [_sat(0), _contrast(1.25)]),
  _f('Hefe', [_sat(1.35), _contrast(1.2), _tint(1.08, 1.0, 0.9)]),
  _f('Nashville', [_sat(1.2), _contrast(1.05), _bright(18), _tint(1.12, 0.98, 0.95)]),
  _f('Sutro', [_sat(0.7), _contrast(1.2), _bright(-15), _tint(1.0, 0.95, 0.9)]),
  _f('Toaster', [_sat(1.3), _contrast(1.25), _tint(1.15, 1.0, 0.8)]),
  _f('Walden', [_sat(1.15), _bright(20), _tint(1.1, 1.05, 0.85)]),
  _f('1977', [_sat(1.2), _contrast(0.9), _bright(15), _tint(1.1, 0.97, 1.0)]),
  _f('Kelvin', [_sat(1.4), _contrast(1.1), _tint(1.2, 1.0, 0.7)]),
  _f('Stinson', [_sat(0.8), _contrast(0.9), _bright(22), _tint(1.02, 1.0, 0.97)]),
  _f('Maven', [_sat(0.9), _contrast(1.1), _tint(1.05, 1.02, 0.85)]),
  _f('Ginza', [_sat(1.1), _bright(15), _tint(1.05, 1.02, 0.95)]),
  _f('Dogpatch', [_sat(0.9), _contrast(1.3)]),
  _f('Brooklyn', [_sat(0.9), _bright(10), _tint(1.0, 1.05, 1.0)]),
  _f('Helena', [_sat(1.2), _tint(1.0, 1.05, 0.92)]),
  _f('Ashby', [_sat(0.9), _bright(10), _tint(1.1, 1.0, 0.88)]),
  _f('Charmes', [_sat(1.2), _contrast(1.2), _tint(1.1, 0.95, 0.95)]),
  _f('Siyah Beyaz', [_sat(0)]),
  _f('Canlı', [_sat(1.6)]),
  _f('Pastel', [_sat(0.7), _bright(28)]),
  _f('Dramatik', [_contrast(1.4)]),
  _f('Solgun', [_contrast(0.8), _bright(10)]),
  const FilterItem('Sıcak', [
    1.1, 0, 0, 0, 10, 0, 1, 0, 0, 0, 0, 0, 0.9, 0, -10, 0, 0, 0, 1, 0,
  ]),
  const FilterItem('Soğuk', [
    0.9, 0, 0, 0, -10, 0, 1, 0, 0, 0, 0, 0, 1.1, 0, 10, 0, 0, 0, 1, 0,
  ]),
  const FilterItem('Retro', [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  const FilterItem('Gece', [
    0.7, 0, 0, 0, -10,
    0, 0.8, 0.1, 0, -5,
    0, 0.1, 1.1, 0, 15,
    0, 0, 0, 1, 0,
  ]),
];
