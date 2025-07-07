import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'procedure_detail_screen.dart';

class Procedure {
  final int id;
  final String uuid;
  final String title;
  final String? description;
  final String? category;
  final String? specialty;
  final String? difficultyLevel;
  final int? estimatedDuration;
  final String? objective;
  final bool isPublished;
  final bool isFeatured;
  final int viewCount;
  final double ratingAverage;
  final int ratingCount;
  final DateTime createdAt;

  Procedure({
    required this.id,
    required this.uuid,
    required this.title,
    this.description,
    this.category,
    this.specialty,
    this.difficultyLevel,
    this.estimatedDuration,
    this.objective,
    required this.isPublished,
    required this.isFeatured,
    required this.viewCount,
    required this.ratingAverage,
    required this.ratingCount,
    required this.createdAt,
  });

  factory Procedure.fromJson(Map<String, dynamic> json) {
    return Procedure(
      id: json['id'],
      uuid: json['uuid'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      specialty: json['specialty'],
      difficultyLevel: json['difficulty_level'],
      estimatedDuration: json['estimated_duration'],
      objective: json['objective'],
      isPublished: json['is_published'] ?? false,
      isFeatured: json['is_featured'] ?? false,
      viewCount: json['view_count'] ?? 0,
      ratingAverage: (json['rating_average'] ?? 0.0).toDouble(),
      ratingCount: json['rating_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get displayDuration {
    if (estimatedDuration == null) return 'No especificado';
    if (estimatedDuration! < 60) return '${estimatedDuration}min';
    final hours = estimatedDuration! ~/ 60;
    final minutes = estimatedDuration! % 60;
    return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
  }

  String get displayDifficulty => difficultyLevel ?? 'No especificado';
  String get displayCategory => category ?? 'General';
  String get displaySpecialty => specialty ?? 'General';
}

class ProcedureListScreen extends StatefulWidget {
  const ProcedureListScreen({Key? key}) : super(key: key);

  @override
  State<ProcedureListScreen> createState() => _ProcedureListScreenState();
}

class _ProcedureListScreenState extends State<ProcedureListScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Procedure> _procedures = [];
  List<Procedure> _featuredProcedures = [];
  List<Procedure> _filteredProcedures = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _selectedCategory;
  String? _selectedSpecialty;
  String? _selectedDifficulty;
  String _searchQuery = '';

  final List<String> _categories = [
    'Emergencias',
    'Cirugía Menor',
    'Diagnóstico',
    'Terapéutico',
    'Preventivo',
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

  final List<String> _difficulties = [
    'Básico',
    'Intermedio',
    'Avanzado',
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
        _apiService.getProcedures(limit: 50),
        _apiService.getFeaturedProcedures(limit: 10),
      ];
      
      final results = await Future.wait(futures);
      
      final procedures = (results[0] as List<Map<String, dynamic>>)
          .map((json) => Procedure.fromJson(json))
          .toList();
      
      final featuredProcedures = (results[1] as List<Map<String, dynamic>>)
          .map((json) => Procedure.fromJson(json))
          .toList();

      setState(() {
        _procedures = procedures;
        _featuredProcedures = featuredProcedures;
        _filteredProcedures = procedures;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando procedimientos: $e'),
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
    List<Procedure> filtered = _procedures;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((procedure) =>
          procedure.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (procedure.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (procedure.objective ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((procedure) => procedure.category == _selectedCategory).toList();
    }

    if (_selectedSpecialty != null) {
      filtered = filtered.where((procedure) => procedure.specialty == _selectedSpecialty).toList();
    }

    if (_selectedDifficulty != null) {
      filtered = filtered.where((procedure) => procedure.difficultyLevel == _selectedDifficulty).toList();
    }

    setState(() {
      _filteredProcedures = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSpecialty = null;
      _selectedDifficulty = null;
      _searchQuery = '';
      _filteredProcedures = _procedures;
    });
  }

  void _navigateToProcedureDetail(Procedure procedure) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcedureDetailScreen(procedureId: procedure.id),
      ),
    );
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'básico':
        return Colors.green;
      case 'intermedio':
        return Colors.orange;
      case 'avanzado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'emergencias':
        return Icons.emergency;
      case 'cirugía menor':
        return Icons.medical_services;
      case 'diagnóstico':
        return Icons.search;
      case 'terapéutico':
        return Icons.healing;
      case 'preventivo':
        return Icons.shield;
      default:
        return Icons.list_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procedimientos Médicos'),
        backgroundColor: Colors.teal,
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
                  hintText: 'Buscar procedimientos...',
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
              color: Colors.teal.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtros activos: ${_getActiveFiltersText()}',
                      style: const TextStyle(color: Colors.teal, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Limpiar', style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProceduresList(_filteredProcedures),
                _buildProceduresList(_featuredProcedures),
                _buildCategoriesView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProceduresList(List<Procedure> procedures) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (procedures.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay procedimientos disponibles',
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
        itemCount: procedures.length,
        itemBuilder: (context, index) {
          final procedure = procedures[index];
          return ProcedureCard(
            procedure: procedure,
            onTap: () => _navigateToProcedureDetail(procedure),
            getDifficultyColor: _getDifficultyColor,
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

    final categoryGroups = <String, List<Procedure>>{};
    for (final procedure in _procedures) {
      final category = procedure.displayCategory;
      categoryGroups.putIfAbsent(category, () => []).add(procedure);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoryGroups.length,
      itemBuilder: (context, index) {
        final category = categoryGroups.keys.elementAt(index);
        final procedures = categoryGroups[category]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: Icon(_getCategoryIcon(category), color: Colors.teal),
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${procedures.length} procedimientos'),
            children: procedures.map((procedure) => ListTile(
              title: Text(procedure.title),
              subtitle: Text(procedure.displayDuration),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
              onTap: () => _navigateToProcedureDetail(procedure),
            )).toList(),
          ),
        );
      },
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null ||
           _selectedSpecialty != null ||
           _selectedDifficulty != null ||
           _searchQuery.isNotEmpty;
  }

  String _getActiveFiltersText() {
    final filters = <String>[];
    if (_selectedCategory != null) filters.add('Categoría: $_selectedCategory');
    if (_selectedSpecialty != null) filters.add('Especialidad: $_selectedSpecialty');
    if (_selectedDifficulty != null) filters.add('Dificultad: $_selectedDifficulty');
    if (_searchQuery.isNotEmpty) filters.add('Búsqueda: $_searchQuery');
    return filters.join(', ');
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
              const Text('Dificultad:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedDifficulty,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todas')),
                  ..._difficulties.map((difficulty) => DropdownMenuItem<String>(
                    value: difficulty,
                    child: Text(difficulty),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedDifficulty = value),
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

class ProcedureCard extends StatelessWidget {
  final Procedure procedure;
  final VoidCallback onTap;
  final Color Function(String?) getDifficultyColor;
  final IconData Function(String?) getCategoryIcon;

  const ProcedureCard({
    Key? key,
    required this.procedure,
    required this.onTap,
    required this.getDifficultyColor,
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
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getCategoryIcon(procedure.category),
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          procedure.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
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
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                procedure.displayCategory,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (procedure.isFeatured) ...[
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
              
              if (procedure.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  procedure.description!,
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
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    procedure.displayDuration,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: getDifficultyColor(procedure.difficultyLevel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: getDifficultyColor(procedure.difficultyLevel).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      procedure.displayDifficulty,
                      style: TextStyle(
                        fontSize: 12,
                        color: getDifficultyColor(procedure.difficultyLevel),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (procedure.ratingCount > 0) ...[
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      procedure.ratingAverage.toStringAsFixed(1),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      ' (${procedure.ratingCount})',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 2),
                  Text(
                    '${procedure.viewCount}',
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