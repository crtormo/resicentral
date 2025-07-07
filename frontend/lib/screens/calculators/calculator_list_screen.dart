import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'curb65_screen.dart';

class Calculator {
  final String key;
  final String name;
  final String description;
  final String category;
  final List<Map<String, dynamic>> parameters;

  Calculator({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    required this.parameters,
  });

  factory Calculator.fromJson(String key, Map<String, dynamic> json) {
    return Calculator(
      key: key,
      name: json['name'],
      description: json['description'],
      category: json['category'],
      parameters: List<Map<String, dynamic>>.from(json['parameters']),
    );
  }
}

class CalculatorListScreen extends StatefulWidget {
  const CalculatorListScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorListScreen> createState() => _CalculatorListScreenState();
}

class _CalculatorListScreenState extends State<CalculatorListScreen> {
  final ApiService _apiService = ApiService();
  
  List<Calculator> _calculators = [];
  List<Calculator> _filteredCalculators = [];
  bool _isLoading = false;
  String? _selectedCategory;

  final List<String> _categories = [
    'Respiratorio',
    'Cardiovascular',
    'Neurológico',
    'Endocrino',
  ];

  @override
  void initState() {
    super.initState();
    _loadCalculators();
  }

  Future<void> _loadCalculators() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final calculatorsData = await _apiService.getCalculators();
      final calculators = <Calculator>[];
      
      calculatorsData.forEach((key, value) {
        calculators.add(Calculator.fromJson(key, value));
      });
      
      setState(() {
        _calculators = calculators;
        _filteredCalculators = calculators;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando calculadoras: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _filteredCalculators = category == null
          ? _calculators
          : _calculators.where((calc) => calc.category == category).toList();
    });
  }

  void _navigateToCalculator(Calculator calculator) {
    Widget? screen;
    
    switch (calculator.key) {
      case 'curb65':
        screen = const CURB65Screen();
        break;
      // Agregar más calculadoras aquí según sea necesario
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta calculadora no está implementada aún'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
    }

    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen!),
      );
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Respiratorio':
        return Colors.lightBlue;
      case 'Cardiovascular':
        return Colors.red;
      case 'Neurológico':
        return Colors.purple;
      case 'Endocrino':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Respiratorio':
        return Icons.air;
      case 'Cardiovascular':
        return Icons.favorite;
      case 'Neurológico':
        return Icons.psychology;
      case 'Endocrino':
        return Icons.scatter_plot;
      default:
        return Icons.calculate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadoras Clínicas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtro por categoría
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
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Filtrar por categoría',
                prefixIcon: const Icon(Icons.filter_list, color: Colors.indigo),
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
                  child: Text('Todas las categorías'),
                ),
                ..._categories.map((category) =>
                  DropdownMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          color: _getCategoryColor(category),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: _filterByCategory,
            ),
          ),
          
          // Lista de calculadoras
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCalculators.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calculate,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hay calculadoras disponibles',
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
                        itemCount: _filteredCalculators.length,
                        itemBuilder: (context, index) {
                          final calculator = _filteredCalculators[index];
                          return CalculatorCard(
                            calculator: calculator,
                            categoryColor: _getCategoryColor(calculator.category),
                            categoryIcon: _getCategoryIcon(calculator.category),
                            onTap: () => _navigateToCalculator(calculator),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class CalculatorCard extends StatelessWidget {
  final Calculator calculator;
  final Color categoryColor;
  final IconData categoryIcon;
  final VoidCallback onTap;

  const CalculatorCard({
    Key? key,
    required this.calculator,
    required this.categoryColor,
    required this.categoryIcon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calculator.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: categoryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            calculator.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
              
              const SizedBox(height: 16),
              
              Text(
                calculator.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.justify,
              ),
              
              const SizedBox(height: 16),
              
              // Información de parámetros
              Row(
                children: [
                  Icon(
                    Icons.assignment,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${calculator.parameters.length} parámetros',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calculate,
                          size: 14,
                          color: Colors.indigo,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Calcular',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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

class CalculatorInfoScreen extends StatelessWidget {
  final Calculator calculator;

  const CalculatorInfoScreen({Key? key, required this.calculator}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(calculator.name),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descripción',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      calculator.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Parámetros requeridos:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Expanded(
              child: ListView.builder(
                itemCount: calculator.parameters.length,
                itemBuilder: (context, index) {
                  final parameter = calculator.parameters[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(parameter['label']),
                      subtitle: Text('Tipo: ${parameter['type']}'),
                      trailing: parameter['unit'] != null
                          ? Chip(
                              label: Text(parameter['unit']),
                              backgroundColor: Colors.grey[200],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}