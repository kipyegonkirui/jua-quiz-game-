// GENERATED from the scenery strips in assets/journey/. Node positions are
// normalised (0-1) over each strip image, ordered level 1 (bottom) -> 10 (top).
import 'dart:ui' show Offset;

class JourneyRegion {
  final String id;
  final String title;
  final double aspect; // strip height / width
  final double capAspect; // sky cap height / width (top of the world)
  final double feather; // cross-fade height / width with the strip below
  final List<Offset> nodes;
  final List<String> props;
  const JourneyRegion({required this.id, required this.title, required this.aspect, required this.capAspect, required this.feather, required this.nodes, required this.props});
  String get stripAsset => 'assets/journey/strips/$id.png';
  String get startAsset => 'assets/journey/strips/${id}_start.png';
  String get capAsset => 'assets/journey/caps/$id.png';
}

const List<JourneyRegion> kJourneyRegions = [
  JourneyRegion(id: 'meadow', title: 'Green Meadow', aspect: 2.64567, capAspect: 0.75591, feather: 0.11024,
    nodes: [Offset(0.5944, 0.8512), Offset(0.511, 0.7992), Offset(0.4463, 0.7437), Offset(0.4305, 0.6834), Offset(0.4784, 0.626), Offset(0.5834, 0.5802), Offset(0.7062, 0.5409), Offset(0.8122, 0.4957), Offset(0.8051, 0.4368), Offset(0.6962, 0.3929)],
    props: ['assets/journey/props/tree_green.png', 'assets/journey/props/tree_purple.png']),
  JourneyRegion(id: 'savanna', title: 'Golden Savanna', aspect: 2.34694, capAspect: 0.58503, feather: 0.09524,
    nodes: [Offset(0.5832, 0.8551), Offset(0.3736, 0.7833), Offset(0.3411, 0.6768), Offset(0.5054, 0.5879), Offset(0.7185, 0.5178), Offset(0.8588, 0.4252), Offset(0.7061, 0.3373), Offset(0.4926, 0.269), Offset(0.5842, 0.1833), Offset(0.7758, 0.1217)],
    props: ['assets/journey/props/cactus.png', 'assets/journey/props/rock_a.png']),
  JourneyRegion(id: 'coast', title: 'Sunny Coast', aspect: 1.94767, capAspect: 0.56977, feather: 0.0814,
    nodes: [Offset(0.7647, 0.8507), Offset(0.7433, 0.7617), Offset(0.6147, 0.6974), Offset(0.5045, 0.6252), Offset(0.4782, 0.5344), Offset(0.5, 0.4432), Offset(0.465, 0.3553), Offset(0.3178, 0.3029), Offset(0.3049, 0.215), Offset(0.2669, 0.1254)],
    props: ['assets/journey/props/palm.png', 'assets/journey/props/boat.png']),
  JourneyRegion(id: 'snow', title: 'Snowy Peaks', aspect: 2.38514, capAspect: 0.54054, feather: 0.09459,
    nodes: [Offset(0.4003, 0.8584), Offset(0.5787, 0.7821), Offset(0.725, 0.6955), Offset(0.6814, 0.5958), Offset(0.5206, 0.5163), Offset(0.357, 0.4395), Offset(0.4269, 0.3477), Offset(0.6593, 0.3031), Offset(0.5439, 0.2215), Offset(0.4465, 0.1473)],
    props: ['assets/journey/props/igloo.png', 'assets/journey/props/rock_flower.png']),
  JourneyRegion(id: 'candy', title: 'Sweet Valley', aspect: 2.72857, capAspect: 0.35714, feather: 0.1,
    nodes: [Offset(0.7802, 0.8691), Offset(0.6361, 0.7995), Offset(0.4521, 0.7425), Offset(0.3981, 0.6593), Offset(0.5393, 0.5888), Offset(0.7048, 0.5251), Offset(0.6817, 0.4436), Offset(0.4839, 0.3936), Offset(0.3518, 0.3286), Offset(0.5071, 0.2618)],
    props: ['assets/journey/props/tree_pink.png', 'assets/journey/props/tree_purple.png']),
];
