import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class Shift {
  final int id;
  final String uuid;
  final String title;
  final String? description;
  final String shiftType;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final String? department;
  final String status;
  final bool isRecurring;
  final String? notes;
  final String? color;
  final String priority;
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final double durationHours;

  Shift({
    required this.id,
    required this.uuid,
    required this.title,
    this.description,
    required this.shiftType,
    required this.startDate,
    required this.endDate,
    this.location,
    this.department,
    required this.status,
    required this.isRecurring,
    this.notes,
    this.color,
    required this.priority,
    required this.reminderEnabled,
    required this.reminderMinutesBefore,
    required this.durationHours,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      uuid: json['uuid'],
      title: json['title'],
      description: json['description'],
      shiftType: json['shift_type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      location: json['location'],
      department: json['department'],
      status: json['status'],
      isRecurring: json['is_recurring'] ?? false,
      notes: json['notes'],
      color: json['color'],
      priority: json['priority'] ?? 'normal',
      reminderEnabled: json['reminder_enabled'] ?? true,
      reminderMinutesBefore: json['reminder_minutes_before'] ?? 60,
      durationHours: (json['duration_hours'] ?? 0.0).toDouble(),
    );
  }

  Color get displayColor {
    if (color != null && color!.isNotEmpty) {
      try {
        return Color(int.parse(color!.replaceFirst('#', '0xFF')));
      } catch (e) {
        return _getDefaultColor();
      }
    }
    return _getDefaultColor();
  }

  Color _getDefaultColor() {
    switch (shiftType) {
      case 'mañana':
        return Colors.orange;
      case 'tarde':
        return Colors.blue;
      case 'noche':
        return Colors.indigo;
      case 'guardia':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get timeRange {
    final formatter = DateFormat('HH:mm');
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  String get formattedDuration {
    if (durationHours < 1) {
      return '${(durationHours * 60).round()}min';
    } else if (durationHours % 1 == 0) {
      return '${durationHours.round()}h';
    } else {
      final hours = durationHours.floor();
      final minutes = ((durationHours - hours) * 60).round();
      return '${hours}h ${minutes}min';
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ApiService _apiService = ApiService();
  
  late final ValueNotifier<List<Shift>> _selectedShifts;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Shift>> _shifts = {};
  bool _isLoading = false;
  Shift? _activeShift;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedShifts = ValueNotifier(_getShiftsForDay(_selectedDay!));
    _loadShifts();
    _loadActiveShift();
  }

  List<Shift> _getShiftsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _shifts[normalizedDay] ?? [];
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final year = _focusedDay.year;
      final month = _focusedDay.month;
      
      final shiftsData = await _apiService.get('/shifts/month/$year/$month');
      
      if (shiftsData.isSuccess && shiftsData.data != null) {
        final shifts = (shiftsData.data! as List)
            .map((json) => Shift.fromJson(json))
            .toList();
        
        final Map<DateTime, List<Shift>> shiftsByDay = {};
        
        for (final shift in shifts) {
          final day = DateTime(shift.startDate.year, shift.startDate.month, shift.startDate.day);
          if (shiftsByDay[day] == null) {
            shiftsByDay[day] = [];
          }
          shiftsByDay[day]!.add(shift);
        }
        
        setState(() {
          _shifts = shiftsByDay;
          _selectedShifts.value = _getShiftsForDay(_selectedDay!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando turnos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActiveShift() async {
    try {
      final response = await _apiService.get('/shifts/active');
      if (response.isSuccess && response.data != null) {
        setState(() {
          _activeShift = Shift.fromJson(response.data!);
        });
      }
    } catch (e) {
      print('Error cargando turno activo: $e');
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedShifts.value = _getShiftsForDay(selectedDay);
      });
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadShifts();
  }

  void _showShiftDetails(Shift shift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShiftDetailsModal(shift: shift, onUpdate: _loadShifts),
    );
  }

  void _showCreateShiftDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateShiftDialog(
        selectedDate: _selectedDay ?? DateTime.now(),
        onShiftCreated: _loadShifts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Turnos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
                _selectedShifts.value = _getShiftsForDay(DateTime.now());
              });
              _loadShifts();
            },
            tooltip: 'Ir a hoy',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShifts,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_activeShift != null) _buildActiveShiftCard(),
          _buildCalendar(),
          const Divider(height: 1),
          Expanded(child: _buildShiftsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateShiftDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear nuevo turno',
      ),
    );
  }

  Widget _buildActiveShiftCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _activeShift!.displayColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _activeShift!.displayColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: _activeShift!.displayColor),
              const SizedBox(width: 8),
              const Text(
                'Turno Activo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _activeShift!.displayColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _activeShift!.shiftType.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _activeShift!.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _activeShift!.timeRange,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              if (_activeShift!.location != null) ...[
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _activeShift!.location!,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
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
      child: TableCalendar<Shift>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getShiftsForDay,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mes',
          CalendarFormat.twoWeeks: '2 Semanas',
          CalendarFormat.week: 'Semana',
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red[600]),
          holidayTextStyle: TextStyle(color: Colors.red[600]),
          selectedDecoration: const BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
          formatButtonTextStyle: TextStyle(color: Colors.white),
        ),
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: _onPageChanged,
      ),
    );
  }

  Widget _buildShiftsList() {
    return Container(
      color: Colors.grey[50],
      child: ValueListenableBuilder<List<Shift>>(
        valueListenable: _selectedShifts,
        builder: (context, shifts, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (shifts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay turnos programados',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDay != null 
                        ? 'para ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
                        : 'para esta fecha',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateShiftDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Turno'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              return ShiftCard(
                shift: shift,
                onTap: () => _showShiftDetails(shift),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _selectedShifts.dispose();
    super.dispose();
  }
}

class ShiftCard extends StatelessWidget {
  final Shift shift;
  final VoidCallback onTap;

  const ShiftCard({
    Key? key,
    required this.shift,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: shift.displayColor.withOpacity(0.3)),
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
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: shift.displayColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shift.timeRange,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shift.displayColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          shift.shiftType.toUpperCase(),
                          style: TextStyle(
                            color: shift.displayColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shift.formattedDuration,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (shift.location != null || shift.department != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (shift.location != null) ...[
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        shift.location!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                    if (shift.location != null && shift.department != null)
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                    if (shift.department != null) ...[
                      Icon(Icons.local_hospital, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        shift.department!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
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

class ShiftDetailsModal extends StatelessWidget {
  final Shift shift;
  final VoidCallback onUpdate;

  const ShiftDetailsModal({
    Key? key,
    required this.shift,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: shift.displayColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.schedule,
                              color: shift.displayColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shift.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: shift.displayColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    shift.shiftType.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildInfoRow(Icons.access_time, 'Horario', shift.timeRange),
                      _buildInfoRow(Icons.timer, 'Duración', shift.formattedDuration),
                      
                      if (shift.location != null)
                        _buildInfoRow(Icons.location_on, 'Ubicación', shift.location!),
                      
                      if (shift.department != null)
                        _buildInfoRow(Icons.local_hospital, 'Servicio', shift.department!),
                      
                      _buildInfoRow(Icons.flag, 'Estado', shift.status),
                      _buildInfoRow(Icons.priority_high, 'Prioridad', shift.priority),
                      
                      if (shift.description != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Descripción',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shift.description!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                      
                      if (shift.notes != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Notas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            shift.notes!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implementar edición de turno
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implementar eliminación de turno
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Eliminar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
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
}

class CreateShiftDialog extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onShiftCreated;

  const CreateShiftDialog({
    Key? key,
    required this.selectedDate,
    required this.onShiftCreated,
  }) : super(key: key);

  @override
  State<CreateShiftDialog> createState() => _CreateShiftDialogState();
}

class _CreateShiftDialogState extends State<CreateShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _notesController = TextEditingController();

  String _shiftType = 'mañana';
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  String _priority = 'normal';
  bool _isCreating = false;

  final List<String> _shiftTypes = ['mañana', 'tarde', 'noche', 'guardia'];
  final List<String> _priorities = ['baja', 'normal', 'alta', 'urgente'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nuevo Turno'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El título es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _shiftType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Turno *',
                    border: OutlineInputBorder(),
                  ),
                  items: _shiftTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.substring(0, 1).toUpperCase() + type.substring(1)),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _shiftType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (time != null) {
                            setState(() {
                              _startTime = time;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hora Inicio *',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_startTime.format(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _endTime,
                          );
                          if (time != null) {
                            setState(() {
                              _endTime = time;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hora Fin *',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_endTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Servicio/Departamento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(),
                  ),
                  items: _priorities.map((priority) => DropdownMenuItem(
                    value: priority,
                    child: Text(priority.substring(0, 1).toUpperCase() + priority.substring(1)),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _priority = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createShift,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _createShift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final startDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final shiftData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'shift_type': _shiftType,
        'start_date': startDateTime.toIso8601String(),
        'end_date': endDateTime.toIso8601String(),
        'location': _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        'department': _departmentController.text.trim().isEmpty 
            ? null 
            : _departmentController.text.trim(),
        'priority': _priority,
        'notes': _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        'status': 'programado',
      };

      final ApiService apiService = ApiService();
      final response = await apiService.post('/shifts/', shiftData);

      if (response.isSuccess) {
        widget.onShiftCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response.error ?? 'Error desconocido');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando turno: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}