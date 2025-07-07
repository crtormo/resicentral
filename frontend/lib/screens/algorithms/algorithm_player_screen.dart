import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class AlgorithmNode {
  final int id;
  final String uuid;
  final String nodeType;
  final String title;
  final String? content;
  final String? question;
  final String? actionDescription;
  final String? inputType;
  final List<String> inputOptions;
  final Map<String, dynamic> validationRules;
  final double positionX;
  final double positionY;
  final String? color;
  final String? icon;
  final int orderIndex;

  AlgorithmNode({
    required this.id,
    required this.uuid,
    required this.nodeType,
    required this.title,
    this.content,
    this.question,
    this.actionDescription,
    this.inputType,
    this.inputOptions = const [],
    this.validationRules = const {},
    required this.positionX,
    required this.positionY,
    this.color,
    this.icon,
    required this.orderIndex,
  });

  factory AlgorithmNode.fromJson(Map<String, dynamic> json) {
    List<String> parseOptions(String? optionsJson) {
      if (optionsJson == null || optionsJson.isEmpty) return [];
      try {
        final decoded = jsonDecode(optionsJson);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
        return [];
      } catch (e) {
        return [];
      }
    }

    Map<String, dynamic> parseValidation(String? validationJson) {
      if (validationJson == null || validationJson.isEmpty) return {};
      try {
        final decoded = jsonDecode(validationJson);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {};
      } catch (e) {
        return {};
      }
    }

    return AlgorithmNode(
      id: json['id'],
      uuid: json['uuid'],
      nodeType: json['node_type'],
      title: json['title'],
      content: json['content'],
      question: json['question'],
      actionDescription: json['action_description'],
      inputType: json['input_type'],
      inputOptions: parseOptions(json['input_options']),
      validationRules: parseValidation(json['validation_rules']),
      positionX: (json['position_x'] ?? 0.0).toDouble(),
      positionY: (json['position_y'] ?? 0.0).toDouble(),
      color: json['color'],
      icon: json['icon'],
      orderIndex: json['order_index'] ?? 0,
    );
  }
}

class AlgorithmEdge {
  final int id;
  final String uuid;
  final int fromNodeId;
  final int toNodeId;
  final String? label;
  final String? condition;
  final String? conditionType;
  final String? conditionValue;
  final String? color;
  final String lineStyle;
  final int thickness;
  final int orderIndex;

  AlgorithmEdge({
    required this.id,
    required this.uuid,
    required this.fromNodeId,
    required this.toNodeId,
    this.label,
    this.condition,
    this.conditionType,
    this.conditionValue,
    this.color,
    this.lineStyle = 'solid',
    this.thickness = 2,
    required this.orderIndex,
  });

  factory AlgorithmEdge.fromJson(Map<String, dynamic> json) {
    return AlgorithmEdge(
      id: json['id'],
      uuid: json['uuid'],
      fromNodeId: json['from_node_id'],
      toNodeId: json['to_node_id'],
      label: json['label'],
      condition: json['condition'],
      conditionType: json['condition_type'],
      conditionValue: json['condition_value'],
      color: json['color'],
      lineStyle: json['line_style'] ?? 'solid',
      thickness: json['thickness'] ?? 2,
      orderIndex: json['order_index'] ?? 0,
    );
  }
}

class AlgorithmPlayerScreen extends StatefulWidget {
  final int algorithmId;

  const AlgorithmPlayerScreen({Key? key, required this.algorithmId}) : super(key: key);

  @override
  State<AlgorithmPlayerScreen> createState() => _AlgorithmPlayerScreenState();
}

class _AlgorithmPlayerScreenState extends State<AlgorithmPlayerScreen> {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _algorithm;
  List<AlgorithmNode> _nodes = [];
  List<AlgorithmEdge> _edges = [];
  AlgorithmNode? _currentNode;
  Map<String, dynamic> _userResponses = {};
  List<AlgorithmNode> _nodeHistory = [];
  
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadAlgorithm();
  }

  Future<void> _loadAlgorithm() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final algorithmData = await _apiService.getAlgorithmComplete(widget.algorithmId);
      
      await _apiService.incrementAlgorithmViews(widget.algorithmId);
      
      final nodes = (algorithmData['nodes'] as List<dynamic>)
          .map((json) => AlgorithmNode.fromJson(json))
          .toList();
      
      final edges = (algorithmData['edges'] as List<dynamic>)
          .map((json) => AlgorithmEdge.fromJson(json))
          .toList();

      // Encontrar nodo inicial
      AlgorithmNode? startNode;
      if (algorithmData['start_node_id'] != null) {
        startNode = nodes.firstWhere(
          (node) => node.id == algorithmData['start_node_id'],
          orElse: () => nodes.firstWhere((node) => node.nodeType == 'start'),
        );
      } else {
        startNode = nodes.firstWhere(
          (node) => node.nodeType == 'start',
          orElse: () => nodes.first,
        );
      }

      setState(() {
        _algorithm = algorithmData;
        _nodes = nodes;
        _edges = edges;
        _currentNode = startNode;
        _nodeHistory = [startNode];
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processUserResponse(dynamic response) {
    if (_currentNode == null) return;

    // Guardar respuesta del usuario
    _userResponses[_currentNode!.uuid] = response;

    // Encontrar siguiente nodo basado en la respuesta
    AlgorithmNode? nextNode = _findNextNode(response);
    
    if (nextNode != null) {
      setState(() {
        _currentNode = nextNode;
        _nodeHistory.add(nextNode);
        
        if (nextNode.nodeType == 'end') {
          _isCompleted = true;
          _apiService.incrementAlgorithmUsage(widget.algorithmId);
        }
      });
    }
  }

  AlgorithmNode? _findNextNode(dynamic response) {
    if (_currentNode == null) return null;

    // Buscar edges que salen del nodo actual
    final outgoingEdges = _edges
        .where((edge) => edge.fromNodeId == _currentNode!.id)
        .toList();

    // Ordenar por orderIndex
    outgoingEdges.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Evaluar condiciones
    for (final edge in outgoingEdges) {
      if (_evaluateCondition(edge, response)) {
        return _nodes.firstWhere((node) => node.id == edge.toNodeId);
      }
    }

    return null;
  }

  bool _evaluateCondition(AlgorithmEdge edge, dynamic response) {
    if (edge.condition == null || edge.conditionType == null) {
      return true; // Sin condición específica, tomar este camino
    }

    switch (edge.conditionType) {
      case 'equals':
        return response.toString() == edge.conditionValue;
      case 'greater_than':
        final numResponse = double.tryParse(response.toString());
        final numCondition = double.tryParse(edge.conditionValue ?? '0');
        return numResponse != null && numCondition != null && numResponse > numCondition;
      case 'less_than':
        final numResponse = double.tryParse(response.toString());
        final numCondition = double.tryParse(edge.conditionValue ?? '0');
        return numResponse != null && numCondition != null && numResponse < numCondition;
      case 'contains':
        return response.toString().toLowerCase().contains(edge.conditionValue?.toLowerCase() ?? '');
      case 'true':
        return response == true || response.toString().toLowerCase() == 'true';
      case 'false':
        return response == false || response.toString().toLowerCase() == 'false';
      default:
        return true;
    }
  }

  void _goBack() {
    if (_nodeHistory.length > 1) {
      setState(() {
        _nodeHistory.removeLast();
        _currentNode = _nodeHistory.last;
        _isCompleted = false;
      });
    }
  }

  void _restart() {
    final startNode = _nodes.firstWhere(
      (node) => node.nodeType == 'start',
      orElse: () => _nodes.first,
    );
    
    setState(() {
      _currentNode = startNode;
      _nodeHistory = [startNode];
      _userResponses.clear();
      _isCompleted = false;
    });
  }

  Color _getNodeColor(String nodeType) {
    switch (nodeType) {
      case 'start':
        return Colors.green;
      case 'decision':
        return Colors.blue;
      case 'action':
        return Colors.orange;
      case 'input':
        return Colors.purple;
      case 'end':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNodeIcon(String nodeType) {
    switch (nodeType) {
      case 'start':
        return Icons.play_arrow;
      case 'decision':
        return Icons.help;
      case 'action':
        return Icons.build;
      case 'input':
        return Icons.input;
      case 'end':
        return Icons.flag;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cargando algoritmo...'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _algorithm == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error cargando algoritmo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Error desconocido',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAlgorithm,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_algorithm!['title']),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restart,
            tooltip: 'Reiniciar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: _isCompleted ? _buildCompletionView() : _buildCurrentNodeView(),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final totalNodes = _nodes.length;
    final currentProgress = _nodeHistory.length;
    final progress = totalNodes > 0 ? currentProgress / totalNodes : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.indigo.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso: ${currentProgress}/${totalNodes}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentNodeView() {
    if (_currentNode == null) {
      return const Center(
        child: Text('No hay nodo actual disponible'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNodeHeader(),
          const SizedBox(height: 20),
          _buildNodeContent(),
          const SizedBox(height: 20),
          _buildNodeInput(),
        ],
      ),
    );
  }

  Widget _buildNodeHeader() {
    final nodeColor = _getNodeColor(_currentNode!.nodeType);
    final nodeIcon = _getNodeIcon(_currentNode!.nodeType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: nodeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                nodeIcon,
                color: nodeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentNode!.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: nodeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: nodeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentNode!.nodeType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: nodeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeContent() {
    String? content;
    
    switch (_currentNode!.nodeType) {
      case 'decision':
        content = _currentNode!.question;
        break;
      case 'action':
        content = _currentNode!.actionDescription;
        break;
      default:
        content = _currentNode!.content;
        break;
    }

    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeInput() {
    if (_currentNode!.nodeType == 'end') {
      return const SizedBox.shrink();
    }

    if (_currentNode!.nodeType == 'action') {
      return Card(
        color: Colors.orange.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.build, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Acción requerida',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Realice la acción descrita arriba y luego continúe.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _processUserResponse('completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Acción Completada'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentNode!.nodeType == 'decision') {
      return _buildDecisionInput();
    }

    if (_currentNode!.nodeType == 'input') {
      return _buildDataInput();
    }

    // Para nodos start o cualquier otro tipo
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _processUserResponse('continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionInput() {
    final outgoingEdges = _edges
        .where((edge) => edge.fromNodeId == _currentNode!.id)
        .toList();
    
    outgoingEdges.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Seleccione una opción',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...outgoingEdges.map((edge) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _processUserResponse(edge.conditionValue ?? edge.label ?? 'yes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(edge.label ?? 'Continuar'),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDataInput() {
    final inputType = _currentNode!.inputType ?? 'text';
    final options = _currentNode!.inputOptions;

    return Card(
      color: Colors.purple.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.input, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Ingrese la información',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (inputType == 'select' && options.isNotEmpty) ...[
              ...options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _processUserResponse(option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(option),
                  ),
                ),
              )),
            ] else if (inputType == 'boolean') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _processUserResponse(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sí'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _processUserResponse(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('No'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Ingrese ${inputType == 'number' ? 'un número' : 'texto'}',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: inputType == 'number' ? TextInputType.number : TextInputType.text,
                onFieldSubmitted: (value) => _processUserResponse(value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.green.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Algoritmo Completado!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ha completado exitosamente todos los pasos del algoritmo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _restart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ejecutar Nuevamente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          if (_nodeHistory.length > 1 && !_isCompleted)
            Expanded(
              child: ElevatedButton(
                onPressed: _goBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back),
                    SizedBox(width: 8),
                    Text('Anterior'),
                  ],
                ),
              ),
            ),
          if (_nodeHistory.length > 1 && !_isCompleted) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _restart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Reiniciar'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}