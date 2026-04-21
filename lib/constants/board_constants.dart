import 'package:flutter/material.dart';

class PlayerColor {
  final Color main;
  final Color light;
  final String name;
  const PlayerColor({
    required this.main,
    required this.light,
    required this.name,
  });
}

const Map<int, PlayerColor> kColors = {
  0: PlayerColor(
    main: Color(0xFFef4444),
    light: Color(0xFFfecaca),
    name: 'Red',
  ),
  1: PlayerColor(
    main: Color(0xFF22c55e),
    light: Color(0xFFbbf7d0),
    name: 'Green',
  ),
  2: PlayerColor(
    main: Color(0xFFfacc15),
    light: Color(0xFFfef9c3),
    name: 'Yellow',
  ),
  3: PlayerColor(
    main: Color(0xFF3b82f6),
    light: Color(0xFFbfdbfe),
    name: 'Blue',
  ),
};

const List<Map<String, int>> kPathCoords = [
  {'x': 6, 'y': 13},
  {'x': 6, 'y': 12},
  {'x': 6, 'y': 11},
  {'x': 6, 'y': 10},
  {'x': 6, 'y': 9},
  {'x': 5, 'y': 8},
  {'x': 4, 'y': 8},
  {'x': 3, 'y': 8},
  {'x': 2, 'y': 8},
  {'x': 1, 'y': 8},
  {'x': 0, 'y': 8},
  {'x': 0, 'y': 7},
  {'x': 0, 'y': 6},
  {'x': 1, 'y': 6},
  {'x': 2, 'y': 6},
  {'x': 3, 'y': 6},
  {'x': 4, 'y': 6},
  {'x': 5, 'y': 6},
  {'x': 6, 'y': 5},
  {'x': 6, 'y': 4},
  {'x': 6, 'y': 3},
  {'x': 6, 'y': 2},
  {'x': 6, 'y': 1},
  {'x': 6, 'y': 0},
  {'x': 7, 'y': 0},
  {'x': 8, 'y': 0},
  {'x': 8, 'y': 1},
  {'x': 8, 'y': 2},
  {'x': 8, 'y': 3},
  {'x': 8, 'y': 4},
  {'x': 8, 'y': 5},
  {'x': 9, 'y': 6},
  {'x': 10, 'y': 6},
  {'x': 11, 'y': 6},
  {'x': 12, 'y': 6},
  {'x': 13, 'y': 6},
  {'x': 14, 'y': 6},
  {'x': 14, 'y': 7},
  {'x': 14, 'y': 8},
  {'x': 13, 'y': 8},
  {'x': 12, 'y': 8},
  {'x': 11, 'y': 8},
  {'x': 10, 'y': 8},
  {'x': 9, 'y': 8},
  {'x': 8, 'y': 9},
  {'x': 8, 'y': 10},
  {'x': 8, 'y': 11},
  {'x': 8, 'y': 12},
  {'x': 8, 'y': 13},
  {'x': 8, 'y': 14},
  {'x': 7, 'y': 14},
  {'x': 6, 'y': 14},
];

const Map<int, List<Map<String, int>>> kHomeStretches = {
  0: [
    {'x': 7, 'y': 13},
    {'x': 7, 'y': 12},
    {'x': 7, 'y': 11},
    {'x': 7, 'y': 10},
    {'x': 7, 'y': 9},
  ],
  1: [
    {'x': 1, 'y': 7},
    {'x': 2, 'y': 7},
    {'x': 3, 'y': 7},
    {'x': 4, 'y': 7},
    {'x': 5, 'y': 7},
  ],
  2: [
    {'x': 7, 'y': 1},
    {'x': 7, 'y': 2},
    {'x': 7, 'y': 3},
    {'x': 7, 'y': 4},
    {'x': 7, 'y': 5},
  ],
  3: [
    {'x': 13, 'y': 7},
    {'x': 12, 'y': 7},
    {'x': 11, 'y': 7},
    {'x': 10, 'y': 7},
    {'x': 9, 'y': 7},
  ],
};

const Map<int, int> kStartCells = {0: 0, 1: 13, 2: 26, 3: 39};
const Map<int, int> kWhiteSquares = {0: 50, 1: 11, 2: 24, 3: 37};
const List<int> kSafeZones = [0, 8, 13, 21, 26, 34, 39, 47];
const Map<int, List<int>> kMyStops = {
  0: [0, 47],
  1: [13, 8],
  2: [26, 21],
  3: [39, 34],
};

const Map<int, List<Map<String, double>>> kYardCoords = {
  0: [
    {'x': 2.154, 'y': 11.154},
    {'x': 3.848, 'y': 11.154},
    {'x': 2.154, 'y': 12.848},
    {'x': 3.848, 'y': 12.848},
  ],
  1: [
    {'x': 2.154, 'y': 2.154},
    {'x': 3.848, 'y': 2.154},
    {'x': 2.154, 'y': 3.848},
    {'x': 3.848, 'y': 3.848},
  ],
  2: [
    {'x': 11.154, 'y': 2.154},
    {'x': 12.848, 'y': 2.154},
    {'x': 11.154, 'y': 3.848},
    {'x': 12.848, 'y': 3.848},
  ],
  3: [
    {'x': 11.154, 'y': 11.154},
    {'x': 12.848, 'y': 11.154},
    {'x': 11.154, 'y': 12.848},
    {'x': 12.848, 'y': 12.848},
  ],
};

const Map<int, Map<String, double>> kHomeStackCoords = {
  0: {'x': 2.5, 'y': 11.5},
  1: {'x': 2.5, 'y': 2.5},
  2: {'x': 11.5, 'y': 2.5},
  3: {'x': 11.5, 'y': 11.5},
};

const Map<int, Map<String, double>> kPrisonCoords = {
  0: {'x': 1.0, 'y': 9.5},
  1: {'x': 1.0, 'y': 0.5},
  2: {'x': 10.0, 'y': 0.5},
  3: {'x': 10.0, 'y': 9.5},
};
