import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'algorithm_player_screen.dart';

class Algorithm {
  final int id;
  final String uuid;
  final String title;
  final String? description;
  final String? category;
  final String? specialty;
  final String algorithmType;
  final bool isPublished;
  final bool isFeatured;
  final int viewCount;
  final int usageCount;
  final DateTime createdAt;

  Algorithm({
    required this.id,
    required this.uuid,
    required this.title,
    this.description,
    this.category,
    this.specialty,
    required this.algorithmType,
    required this.isPublished,
    required this.isFeatured,
    required this.viewCount,
    required this.usageCount,
    required this.createdAt,
  });

  factory Algorithm.fromJson(Map<String, dynamic> json) {
    return Algorithm(
      id: json['id'],
      uuid: json['uuid'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      specialty: json['specialty'],
      algorithmType: json['algorithm_type'],
      isPublished: json['is_published'] ?? false,
      isFeatured: json['is_featured'] ?? false,
      viewCount: json['view_count'] ?? 0,
      usageCount: json['usage_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get displayType {
    switch (algorithmType) {
      case 'decision_tree':
        return 'Árbol de Decisión';
      case 'flowchart':
        return 'Diagrama de Flujo';
      case 'checklist':
        return 'Lista de Verificación';
      default:
        return 'Algoritmo';
    }
  }

  String get displayCategory => category ?? 'General';
  String get displaySpecialty => specialty ?? 'General';
}

class AlgorithmListScreen extends StatefulWidget {
  const AlgorithmListScreen({Key? key}) : super(key: key);

  @override
  State<AlgorithmListScreen> createState() => _AlgorithmListScreenState();
}

class _AlgorithmListScreenState extends State<AlgorithmListScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Algorithm> _algorithms = [];
  List<Algorithm> _featuredAlgorithms = [];
  List<Algorithm> _filteredAlgorithms = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _selectedCategory;
  String? _selectedSpecialty;
  String? _selectedType;
  String _searchQuery = '';

  final List<String> _categories = [
    'Diagnóstico',
    'Tratamiento',
    'Emergencias',
    'Prevención',
    'Seguimiento',
  ];

  final List<String> _specialties = [
    'Medicina Interna',
    'Emergencias',
    'Cardiología',
    'Neurología',
    'Traumatología',
    'Ginecología',
    'Pediatría',
  ];

  final List<String> _types = [
    'decision_tree',
    'flowchart',
    'checklist',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = [
        _apiService.getAlgorithms(limit: 50),
        _apiService.getFeaturedAlgorithms(limit: 10),
      ];
      
      final results = await Future.wait(futures);
      
      final algorithms = (results[0] as List<Map<String, dynamic>>)
          .map((json) => Algorithm.fromJson(json))
          .toList();
      
      final featuredAlgorithms = (results[1] as List<Map<String, dynamic>>)
          .map((json) => Algorithm.fromJson(json))
          .toList();

      setState(() {
        _algorithms = algorithms;
        _featuredAlgorithms = featuredAlgorithms;
        _filteredAlgorithms = algorithms;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando algoritmos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Algorithm> filtered = _algorithms;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((algorithm) =>
          algorithm.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (algorithm.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((algorithm) => algorithm.category == _selectedCategory).toList();
    }

    if (_selectedSpecialty != null) {
      filtered = filtered.where((algorithm) => algorithm.specialty == _selectedSpecialty).toList();
    }

    if (_selectedType != null) {
      filtered = filtered.where((algorithm) => algorithm.algorithmType == _selectedType).toList();
    }

    setState(() {
      _filteredAlgorithms = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSpecialty = null;
      _selectedType = null;
      _searchQuery = '';
      _filteredAlgorithms = _algorithms;
    });
  }

  void _navigateToAlgorithmPlayer(Algorithm algorithm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlgorithmPlayerScreen(algorithmId: algorithm.id),
      ),
    );
  }

  Color _getTypeColor(String algorithmType) {
    switch (algorithmType) {
      case 'decision_tree':
        return Colors.green;
      case 'flowchart':
        return Colors.blue;
      case 'checklist':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String algorithmType) {
    switch (algorithmType) {
      case 'decision_tree':
        return Icons.account_tree;
      case 'flowchart':
        return Icons.flow_chart;
      case 'checklist':
        return Icons.checklist;
      default:
        return Icons.algorithm;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'diagnóstico':
        return Icons.search;
      case 'tratamiento':
        return Icons.healing;
      case 'emergencias':
        return Icons.emergency;
      case 'prevención':
        return Icons.shield;
      case 'seguimiento':
        return Icons.timeline;
      default:
        return Icons.algorithm;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Algoritmos Médicos'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _applyFilters();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Todos'),
            Tab(icon: Icon(Icons.star), text: 'Destacados'),
            Tab(icon: Icon(Icons.category), text: 'Categorías'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[100],
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar algoritmos...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
              ),
            ),
          
          if (_hasActiveFilters())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Colors.indigo.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.indigo, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtros activos: ${_getActiveFiltersText()}',
                      style: const TextStyle(color: Colors.indigo, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Limpiar', style: TextStyle(color: Colors.indigo)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAlgorithmsList(_filteredAlgorithms),
                _buildAlgorithmsList(_featuredAlgorithms),
                _buildCategoriesView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmsList(List<Algorithm> algorithms) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (algorithms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.algorithm, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay algoritmos disponibles',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: algorithms.length,
        itemBuilder: (context, index) {
          final algorithm = algorithms[index];
          return AlgorithmCard(
            algorithm: algorithm,
            onTap: () => _navigateToAlgorithmPlayer(algorithm),
            getTypeColor: _getTypeColor,
            getTypeIcon: _getTypeIcon,
            getCategoryIcon: _getCategoryIcon,
          );
        },
      ),
    );
  }

  Widget _buildCategoriesView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final categoryGroups = <String, List<Algorithm>>{};
    for (final algorithm in _algorithms) {
      final category = algorithm.displayCategory;
      categoryGroups.putIfAbsent(category, () => []).add(algorithm);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoryGroups.length,
      itemBuilder: (context, index) {
        final category = categoryGroups.keys.elementAt(index);
        final algorithms = categoryGroups[category]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: Icon(_getCategoryIcon(category), color: Colors.indigo),
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${algorithms.length} algoritmos'),
            children: algorithms.map((algorithm) => ListTile(
              title: Text(algorithm.title),
              subtitle: Text(algorithm.displayType),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
              onTap: () => _navigateToAlgorithmPlayer(algorithm),
            )).toList(),
          ),
        );
      },
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null ||
           _selectedSpecialty != null ||
           _selectedType != null ||
           _searchQuery.isNotEmpty;
  }

  String _getActiveFiltersText() {
    final filters = <String>[];
    if (_selectedCategory != null) filters.add('Categoría: $_selectedCategory');
    if (_selectedSpecialty != null) filters.add('Especialidad: $_selectedSpecialty');
    if (_selectedType != null) filters.add('Tipo: ${_getTypeDisplayName(_selectedType!)}');
    if (_searchQuery.isNotEmpty) filters.add('Búsqueda: $_searchQuery');
    return filters.join(', ');
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'decision_tree':
        return 'Árbol de Decisión';
      case 'flowchart':
        return 'Diagrama de Flujo';
      case 'checklist':
        return 'Lista de Verificación';
      default:
        return type;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Categoría:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todas')),
                  ..._categories.map((category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              
              const SizedBox(height: 16),
              const Text('Especialidad:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedSpecialty,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todas')),
                  ..._specialties.map((specialty) => DropdownMenuItem<String>(
                    value: specialty,
                    child: Text(specialty),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedSpecialty = value),
              ),
              
              const SizedBox(height: 16),
              const Text('Tipo de Algoritmo:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                  ..._types.map((type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(_getTypeDisplayName(type)),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedType = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Limpiar'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class AlgorithmCard extends StatelessWidget {
  final Algorithm algorithm;
  final VoidCallback onTap;
  final Color Function(String) getTypeColor;
  final IconData Function(String) getTypeIcon;
  final IconData Function(String?) getCategoryIcon;

  const AlgorithmCard({
    Key? key,
    required this.algorithm,
    required this.onTap,
    required this.getTypeColor,
    required this.getTypeIcon,
    required this.getCategoryIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: getTypeColor(algorithm.algorithmType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getTypeIcon(algorithm.algorithmType),
                      color: getTypeColor(algorithm.algorithmType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          algorithm.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: getTypeColor(algorithm.algorithmType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                algorithm.displayType,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: getTypeColor(algorithm.algorithmType),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (algorithm.isFeatured) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
              
              if (algorithm.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  algorithm.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.indigo.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      algorithm.displayCategory,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 2),
                  Text(
                    '${algorithm.viewCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.play_arrow, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 2),
                  Text(
                    '${algorithm.usageCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}