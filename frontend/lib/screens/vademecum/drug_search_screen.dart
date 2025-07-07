import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class Drug {
  final int id;
  final String uuid;
  final String name;
  final String? genericName;
  final String? brandNames;
  final String? therapeuticClass;
  final String? mechanismOfAction;
  final String? indications;
  final String? contraindications;
  final String? dosage;
  final String? sideEffects;
  final String? interactions;
  final String? precautions;
  final String? pregnancyCategory;
  final bool pediatricUse;
  final bool geriatricUse;
  final String? routeOfAdministration;
  final String? strength;
  final String? presentation;
  final String? laboratory;
  final String? activeIngredient;
  final bool isPrescriptionOnly;
  final bool isControlledSubstance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Drug({
    required this.id,
    required this.uuid,
    required this.name,
    this.genericName,
    this.brandNames,
    this.therapeuticClass,
    this.mechanismOfAction,
    this.indications,
    this.contraindications,
    this.dosage,
    this.sideEffects,
    this.interactions,
    this.precautions,
    this.pregnancyCategory,
    required this.pediatricUse,
    required this.geriatricUse,
    this.routeOfAdministration,
    this.strength,
    this.presentation,
    this.laboratory,
    this.activeIngredient,
    required this.isPrescriptionOnly,
    required this.isControlledSubstance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Drug.fromJson(Map<String, dynamic> json) {
    return Drug(
      id: json['id'],
      uuid: json['uuid'],
      name: json['name'],
      genericName: json['generic_name'],
      brandNames: json['brand_names'],
      therapeuticClass: json['therapeutic_class'],
      mechanismOfAction: json['mechanism_of_action'],
      indications: json['indications'],
      contraindications: json['contraindications'],
      dosage: json['dosage'],
      sideEffects: json['side_effects'],
      interactions: json['interactions'],
      precautions: json['precautions'],
      pregnancyCategory: json['pregnancy_category'],
      pediatricUse: json['pediatric_use'],
      geriatricUse: json['geriatric_use'],
      routeOfAdministration: json['route_of_administration'],
      strength: json['strength'],
      presentation: json['presentation'],
      laboratory: json['laboratory'],
      activeIngredient: json['active_ingredient'],
      isPrescriptionOnly: json['is_prescription_only'],
      isControlledSubstance: json['is_controlled_substance'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class DrugSearchScreen extends StatefulWidget {
  const DrugSearchScreen({Key? key}) : super(key: key);

  @override
  State<DrugSearchScreen> createState() => _DrugSearchScreenState();
}

class _DrugSearchScreenState extends State<DrugSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  List<Drug> _drugs = [];
  List<Drug> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _selectedTherapeuticClass;

  final List<String> _therapeuticClasses = [
    'Analgésico no opiáceo',
    'AINE',
    'Antibiótico beta-lactámico',
    'Inhibidor de la bomba de protones',
    'Antidiabético biguanida',
    'Estatina',
    'Benzodiacepina',
    'Broncodilatador beta-2 agonista',
  ];

  @override
  void initState() {
    super.initState();
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final drugs = await _apiService.getDrugs();
      setState(() {
        _drugs = drugs.map((json) => Drug.fromJson(json)).toList();
        _searchResults = _drugs;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando fármacos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchDrugs(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = _drugs;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _apiService.searchDrugs(
        query: query,
        therapeuticClass: _selectedTherapeuticClass,
      );
      setState(() {
        _searchResults = response['drugs'].map<Drug>((json) => Drug.fromJson(json)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error buscando fármacos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _filterByTherapeuticClass(String? therapeuticClass) {
    setState(() {
      _selectedTherapeuticClass = therapeuticClass;
    });

    if (_searchController.text.isNotEmpty) {
      _searchDrugs(_searchController.text);
    } else {
      final filtered = therapeuticClass == null 
          ? _drugs 
          : _drugs.where((drug) => 
              drug.therapeuticClass?.toLowerCase().contains(therapeuticClass.toLowerCase()) ?? false
            ).toList();
      
      setState(() {
        _searchResults = filtered;
      });
    }
  }

  void _showDrugDetails(Drug drug) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DrugDetailsBottomSheet(drug: drug),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vademécum'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar fármacos por nombre, principio activo...',
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchDrugs('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: _searchDrugs,
                ),
                const SizedBox(height: 12),
                // Filtro por clase terapéutica
                DropdownButtonFormField<String>(
                  value: _selectedTherapeuticClass,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por clase terapéutica',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas las clases'),
                    ),
                    ..._therapeuticClasses.map((className) =>
                      DropdownMenuItem<String>(
                        value: className,
                        child: Text(className),
                      ),
                    ),
                  ],
                  onChanged: _filterByTherapeuticClass,
                ),
              ],
            ),
          ),
          
          // Lista de resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No se encontraron fármacos',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final drug = _searchResults[index];
                          return DrugCard(
                            drug: drug,
                            onTap: () => _showDrugDetails(drug),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class DrugCard extends StatelessWidget {
  final Drug drug;
  final VoidCallback onTap;

  const DrugCard({
    Key? key,
    required this.drug,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                  Expanded(
                    child: Text(
                      drug.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  if (drug.isPrescriptionOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'Receta',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (drug.isControlledSubstance) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        'Controlado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              if (drug.genericName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Genérico: ${drug.genericName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              
              if (drug.therapeuticClass != null) ...[
                const SizedBox(height: 4),
                Text(
                  drug.therapeuticClass!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              if (drug.strength != null || drug.presentation != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (drug.strength != null) ...[
                      Icon(Icons.medication, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        drug.strength!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (drug.strength != null && drug.presentation != null)
                      Text(' • ', style: TextStyle(color: Colors.grey[600])),
                    if (drug.presentation != null)
                      Text(
                        drug.presentation!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
              
              // Indicadores de uso especial
              if (drug.pediatricUse || drug.geriatricUse) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (drug.pediatricUse) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Pediátrico',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (drug.geriatricUse)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Geriátrico',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DrugDetailsBottomSheet extends StatelessWidget {
  final Drug drug;

  const DrugDetailsBottomSheet({Key? key, required this.drug}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      if (drug.genericName != null)
                        Text(
                          drug.genericName!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection('Información General', [
                    if (drug.therapeuticClass != null)
                      _buildInfoRow('Clase terapéutica', drug.therapeuticClass!),
                    if (drug.activeIngredient != null)
                      _buildInfoRow('Principio activo', drug.activeIngredient!),
                    if (drug.strength != null)
                      _buildInfoRow('Concentración', drug.strength!),
                    if (drug.presentation != null)
                      _buildInfoRow('Presentación', drug.presentation!),
                    if (drug.routeOfAdministration != null)
                      _buildInfoRow('Vía de administración', drug.routeOfAdministration!),
                    if (drug.laboratory != null)
                      _buildInfoRow('Laboratorio', drug.laboratory!),
                  ]),
                  
                  if (drug.mechanismOfAction != null)
                    _buildInfoSection('Mecanismo de Acción', [
                      _buildInfoText(drug.mechanismOfAction!),
                    ]),
                  
                  if (drug.indications != null)
                    _buildInfoSection('Indicaciones', [
                      _buildInfoText(drug.indications!),
                    ]),
                  
                  if (drug.dosage != null)
                    _buildInfoSection('Dosificación', [
                      _buildInfoText(drug.dosage!),
                    ]),
                  
                  if (drug.contraindications != null)
                    _buildInfoSection('Contraindicaciones', [
                      _buildInfoText(drug.contraindications!),
                    ]),
                  
                  if (drug.sideEffects != null)
                    _buildInfoSection('Efectos Secundarios', [
                      _buildInfoText(drug.sideEffects!),
                    ]),
                  
                  if (drug.interactions != null)
                    _buildInfoSection('Interacciones', [
                      _buildInfoText(drug.interactions!),
                    ]),
                  
                  if (drug.precautions != null)
                    _buildInfoSection('Precauciones', [
                      _buildInfoText(drug.precautions!),
                    ]),
                  
                  _buildInfoSection('Información Adicional', [
                    if (drug.pregnancyCategory != null)
                      _buildInfoRow('Categoría embarazo', drug.pregnancyCategory!),
                    _buildInfoRow('Uso pediátrico', drug.pediatricUse ? 'Sí' : 'No'),
                    _buildInfoRow('Uso geriátrico', drug.geriatricUse ? 'Sí' : 'No'),
                    _buildInfoRow('Requiere receta', drug.isPrescriptionOnly ? 'Sí' : 'No'),
                    _buildInfoRow('Sustancia controlada', drug.isControlledSubstance ? 'Sí' : 'No'),
                  ]),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.justify,
      ),
    );
  }
}