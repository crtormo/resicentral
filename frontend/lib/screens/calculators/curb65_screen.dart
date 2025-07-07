import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class CalculatorResult {
  final double score;
  final String riskLevel;
  final String interpretation;
  final String recommendations;

  CalculatorResult({
    required this.score,
    required this.riskLevel,
    required this.interpretation,
    required this.recommendations,
  });

  factory CalculatorResult.fromJson(Map<String, dynamic> json) {
    return CalculatorResult(
      score: json['score'].toDouble(),
      riskLevel: json['risk_level'],
      interpretation: json['interpretation'],
      recommendations: json['recommendations'],
    );
  }
}

class CURB65Screen extends StatefulWidget {
  const CURB65Screen({Key? key}) : super(key: key);

  @override
  State<CURB65Screen> createState() => _CURB65ScreenState();
}

class _CURB65ScreenState extends State<CURB65Screen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _ureaController = TextEditingController();
  final TextEditingController _respiratoryRateController = TextEditingController();
  final TextEditingController _systolicBPController = TextEditingController();
  final TextEditingController _diastolicBPController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  
  // Form values
  bool _confusion = false;
  bool _isCalculating = false;
  CalculatorResult? _result;

  Color _getRiskLevelColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'bajo':
        return Colors.green;
      case 'moderado':
        return Colors.orange;
      case 'alto':
        return Colors.red;
      case 'severo':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskLevelIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'bajo':
        return Icons.check_circle;
      case 'moderado':
        return Icons.warning;
      case 'alto':
        return Icons.error;
      case 'severo':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  Future<void> _calculateCURB65() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCalculating = true;
      _result = null;
    });

    try {
      final result = await _apiService.calculateCURB65(
        confusion: _confusion,
        urea: double.parse(_ureaController.text),
        respiratoryRate: int.parse(_respiratoryRateController.text),
        bloodPressureSystolic: int.parse(_systolicBPController.text),
        bloodPressureDiastolic: int.parse(_diastolicBPController.text),
        age: int.parse(_ageController.text),
      );
      
      setState(() {
        _result = CalculatorResult.fromJson(result);
      });
      
      // Scroll to results
      _scrollToResults();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculando CURB-65: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCalculating = false;
      });
    }
  }

  void _scrollToResults() {
    // Implementar scroll si es necesario
  }

  void _resetForm() {
    setState(() {
      _confusion = false;
      _result = null;
    });
    _ureaController.clear();
    _respiratoryRateController.clear();
    _systolicBPController.clear();
    _diastolicBPController.clear();
    _ageController.clear();
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CURB-65'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Limpiar formulario',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información de la calculadora
              Card(
                color: Colors.lightBlue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.lightBlue,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Acerca de CURB-65',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El score CURB-65 evalúa la severidad de la neumonía adquirida en la comunidad y ayuda a determinar el lugar de tratamiento (ambulatorio vs. hospitalario).',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Formulario
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parámetros Clínicos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // C - Confusión
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.lightBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'C',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Confusión mental',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Desorientación en tiempo, lugar o persona',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _confusion,
                              onChanged: (value) {
                                setState(() {
                                  _confusion = value;
                                });
                              },
                              activeColor: Colors.lightBlue,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // U - Urea
                      _buildParameterField(
                        letter: 'U',
                        title: 'Urea en sangre',
                        subtitle: 'Valor en mg/dL',
                        controller: _ureaController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese el valor de urea';
                          }
                          final number = double.tryParse(value);
                          if (number == null || number < 0) {
                            return 'Ingrese un valor válido';
                          }
                          return null;
                        },
                        suffix: 'mg/dL',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // R - Respiratory Rate
                      _buildParameterField(
                        letter: 'R',
                        title: 'Frecuencia respiratoria',
                        subtitle: 'Respiraciones por minuto',
                        controller: _respiratoryRateController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese la frecuencia respiratoria';
                          }
                          final number = int.tryParse(value);
                          if (number == null || number < 0 || number > 100) {
                            return 'Ingrese un valor entre 0 y 100';
                          }
                          return null;
                        },
                        suffix: '/min',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // B - Blood Pressure
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'B',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.lightBlue,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Presión arterial',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Sistólica < 90 o diastólica ≤ 60 mmHg',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _systolicBPController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Sistólica',
                                      suffixText: 'mmHg',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Requerido';
                                      }
                                      final number = int.tryParse(value);
                                      if (number == null || number < 0 || number > 300) {
                                        return 'Valor inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _diastolicBPController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Diastólica',
                                      suffixText: 'mmHg',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Requerido';
                                      }
                                      final number = int.tryParse(value);
                                      if (number == null || number < 0 || number > 200) {
                                        return 'Valor inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 65 - Age
                      _buildParameterField(
                        letter: '65',
                        title: 'Edad',
                        subtitle: 'Edad del paciente en años',
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingrese la edad';
                          }
                          final number = int.tryParse(value);
                          if (number == null || number < 0 || number > 150) {
                            return 'Ingrese una edad válida';
                          }
                          return null;
                        },
                        suffix: 'años',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Botón calcular
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCalculating ? null : _calculateCURB65,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCalculating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Calculando...'),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calculate),
                            SizedBox(width: 8),
                            Text(
                              'Calcular CURB-65',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              
              // Resultados
              if (_result != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: _getRiskLevelColor(_result!.riskLevel).withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getRiskLevelIcon(_result!.riskLevel),
                              color: _getRiskLevelColor(_result!.riskLevel),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Resultado CURB-65',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Score
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getRiskLevelColor(_result!.riskLevel).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getRiskLevelColor(_result!.riskLevel).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Score: ',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${_result!.score.toInt()}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _getRiskLevelColor(_result!.riskLevel),
                                ),
                              ),
                              const Text(
                                ' / 5',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getRiskLevelColor(_result!.riskLevel),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Riesgo ${_result!.riskLevel}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Interpretación
                        const Text(
                          'Interpretación:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _result!.interpretation,
                          style: const TextStyle(fontSize: 15),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Recomendaciones
                        const Text(
                          'Recomendaciones:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _result!.recommendations,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterField({
    required String letter,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
    required String suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.lightBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              suffixText: suffix,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ureaController.dispose();
    _respiratoryRateController.dispose();
    _systolicBPController.dispose();
    _diastolicBPController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}