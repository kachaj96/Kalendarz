class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    this.isLocal = false,
  });

  final String id;
  final String name;

  /// Kolor jako wartość ARGB.
  final int color;

  /// Kategoria lokalna jest tylko na tym telefonie i tylko dla wpisów lokalnych.
  final bool isLocal;

  Category copyWith({String? name, int? color}) => Category(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    isLocal: isLocal,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'isLocal': isLocal,
  };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    name: j['name'] as String,
    color: j['color'] as int,
    isLocal: j['isLocal'] as bool? ?? false,
  );
}

const fallbackCategoryId = 'inne';

/// Kategorie wspólne na start. Od etapu ze współdzieleniem trafią do Firestore.
const defaultCategories = <Category>[
  Category(id: 'dom', name: 'Dom', color: 0xFF12808A),
  Category(id: 'praca', name: 'Praca', color: 0xFF2F6FDE),
  Category(id: 'zakupy', name: 'Zakupy', color: 0xFFC75F00),
  Category(id: 'zdrowie', name: 'Zdrowie', color: 0xFFD13438),
  Category(id: 'sport', name: 'Sport', color: 0xFF5E8C0A),
  Category(id: 'rodzina', name: 'Rodzina', color: 0xFF7B4FD0),
  Category(id: 'finanse', name: 'Finanse', color: 0xFF1F8A4C),
  Category(id: fallbackCategoryId, name: 'Inne', color: 0xFF5F6B80),
];

/// Paleta do wyboru przy tworzeniu własnej kategorii (białe napisy mają na niej kontrast).
const categoryPalette = <int>[
  0xFF2F6FDE,
  0xFF12808A,
  0xFF1F8A4C,
  0xFF5E8C0A,
  0xFFC75F00,
  0xFFD13438,
  0xFFC42B8A,
  0xFF7B4FD0,
  0xFF4B5FC7,
  0xFF8A5A44,
  0xFF5F6B80,
  0xFFA8740A,
];
