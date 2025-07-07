import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ChatMessage {
  final String id;
  final String message;
  final String? response;
  final DateTime timestamp;
  final bool isFromUser;
  final bool isLoading;
  final String? error;

  ChatMessage({
    required this.id,
    required this.message,
    this.response,
    required this.timestamp,
    required this.isFromUser,
    this.isLoading = false,
    this.error,
  });

  ChatMessage copyWith({
    String? id,
    String? message,
    String? response,
    DateTime? timestamp,
    bool? isFromUser,
    bool? isLoading,
    String? error,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      response: response ?? this.response,
      timestamp: timestamp ?? this.timestamp,
      isFromUser: isFromUser ?? this.isFromUser,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _apiService = ApiService();
  
  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialSuggestions();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: '''¡Hola! Soy tu asistente médico virtual. 

Estoy aquí para ayudarte con:
• Consultas médicas generales
• Procedimientos clínicos
• Cálculos médicos
• Interpretación de estudios
• Protocolos de emergencia
• Información de medicamentos

¿En qué puedo asistirte hoy?''',
          timestamp: DateTime.now(),
          isFromUser: false,
        ),
      );
    });
  }

  Future<void> _loadInitialSuggestions() async {
    try {
      final response = await _apiService.get('/ai/suggestions');
      if (response.isSuccess && response.data != null) {
        setState(() {
          _suggestions = List<String>.from(response.data!['suggestions'] ?? []);
        });
      }
    } catch (e) {
      // Si no se pueden cargar las sugerencias, usar unas por defecto
      setState(() {
        _suggestions = [
          '¿Cómo prepararse para un turno nocturno?',
          'Protocolo ABCDE en trauma',
          'Calcular score CURB-65',
          'Manejo del paciente crítico',
          'Información sobre medicamentos',
        ];
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message.trim(),
      timestamp: DateTime.now(),
      isFromUser: true,
    );

    final loadingMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch + 1}',
      message: '',
      timestamp: DateTime.now(),
      isFromUser: false,
      isLoading: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(loadingMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _apiService.post('/ai/chat', {
        'message': message,
      });

      if (response.isSuccess && response.data != null) {
        final aiResponse = response.data!['response'] ?? 'Lo siento, no pude procesar tu mensaje.';
        
        setState(() {
          _messages.removeWhere((msg) => msg.id == loadingMessage.id);
          _messages.add(
            ChatMessage(
              id: loadingMessage.id,
              message: aiResponse,
              timestamp: DateTime.now(),
              isFromUser: false,
            ),
          );
          _isTyping = false;
        });
      } else {
        throw Exception(response.error ?? 'Error desconocido');
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
        _messages.add(
          ChatMessage(
            id: loadingMessage.id,
            message: 'Lo siento, ocurrió un error al procesar tu mensaje. Por favor, intenta nuevamente.',
            timestamp: DateTime.now(),
            isFromUser: false,
            error: e.toString(),
          ),
        );
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _useSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _focusNode.requestFocus();
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limpiar Chat'),
          content: const Text('¿Estás seguro de que quieres eliminar todos los mensajes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _messages.clear();
                });
                Navigator.of(context).pop();
                _addWelcomeMessage();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpiar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA Médico'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
            tooltip: 'Limpiar chat',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Información',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_suggestions.isNotEmpty && _messages.length <= 1) _buildSuggestionsBar(),
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _suggestions[index],
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _useSuggestion(_suggestions[index]),
              backgroundColor: Colors.teal.withOpacity(0.1),
              side: BorderSide(color: Colors.teal.withOpacity(0.3)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal,
              child: Icon(
                message.isLoading ? Icons.more_horiz : Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isFromUser 
                    ? Colors.teal 
                    : message.error != null 
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: message.isFromUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: message.isFromUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: message.error != null 
                    ? Border.all(color: Colors.red.withOpacity(0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pensando...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      message.message,
                      style: TextStyle(
                        color: message.isFromUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isFromUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (message.error != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          'Error al enviar',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isFromUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(
                Icons.person,
                color: Colors.grey,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Escribe tu consulta médica...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _messageController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _messageController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: (value) {
                if (!_isTyping) {
                  _sendMessage(value);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton(
              onPressed: _isTyping ? null : () {
                _sendMessage(_messageController.text);
              },
              backgroundColor: _isTyping ? Colors.grey : Colors.teal,
              mini: true,
              child: _isTyping 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Ahora';
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Asistente IA Médico'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Características:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Consultas médicas generales'),
                Text('• Información sobre procedimientos'),
                Text('• Cálculos clínicos'),
                Text('• Interpretación de estudios'),
                Text('• Protocolos de emergencia'),
                Text('• Base de datos de medicamentos'),
                SizedBox(height: 16),
                Text(
                  'Importante:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Este asistente es únicamente para fines educativos y no reemplaza el juicio clínico profesional. Siempre consulta con un médico calificado para decisiones médicas importantes.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }
}

// Widget para casos de uso rápidos
class QuickActionsWidget extends StatelessWidget {
  final Function(String) onActionSelected;

  const QuickActionsWidget({
    super.key,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'title': 'Cálculos Clínicos',
        'subtitle': 'CURB-65, Wells, Glasgow...',
        'icon': Icons.calculate,
        'query': 'Muéstrame los cálculos clínicos disponibles',
      },
      {
        'title': 'Emergencias',
        'subtitle': 'Protocolos y algoritmos',
        'icon': Icons.emergency,
        'query': 'Protocolos de manejo en emergencias',
      },
      {
        'title': 'Procedimientos',
        'subtitle': 'Técnicas y métodos',
        'icon': Icons.medical_services,
        'query': 'Información sobre procedimientos médicos',
      },
      {
        'title': 'Medicamentos',
        'subtitle': 'Vademécum y interacciones',
        'icon': Icons.medication,
        'query': 'Consultar información de medicamentos',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones Rápidas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => onActionSelected(action['query'] as String),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          action['icon'] as IconData,
                          size: 32,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}