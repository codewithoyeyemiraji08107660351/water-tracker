/// Vessel silhouettes drawn by `VesselIcon` on the Switch cup screen.
enum VesselKind { smallCup, glass, mug, tallGlass, bottle, jug }

/// Preset cup sizes from the "Switch cup" screen.
class CupPreset {
  const CupPreset(this.ml, this.kind, this.label);

  final int ml;
  final VesselKind kind;
  final String label;

  static const all = <CupPreset>[
    CupPreset(100, VesselKind.smallCup, 'Small cup'),
    CupPreset(200, VesselKind.glass, 'Glass'),
    CupPreset(300, VesselKind.mug, 'Mug'),
    CupPreset(400, VesselKind.tallGlass, 'Tall glass'),
    CupPreset(500, VesselKind.bottle, 'Bottle'),
    CupPreset(1000, VesselKind.jug, 'Jug'),
  ];

  /// Picks the closest-looking vessel for any amount (used for custom sizes and the timeline).
  static VesselKind kindFor(int ml) {
    if (ml <= 150) return VesselKind.smallCup;
    if (ml <= 250) return VesselKind.glass;
    if (ml <= 350) return VesselKind.mug;
    if (ml <= 450) return VesselKind.tallGlass;
    if (ml <= 750) return VesselKind.bottle;
    return VesselKind.jug;
  }
}
