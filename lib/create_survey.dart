import 'package:flutter/material.dart';
import 'published_surveys.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateSurveyScreen extends StatefulWidget {
  @override
  _CreateSurveyScreenState createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  DateTime? _selectedStartDate;
  TimeOfDay? _selectedStartTime;

  @override
  void dispose() {
    _questionController.dispose();
    _optionControllers.forEach((controller) => controller.dispose());
    _durationController.dispose();
    _startDateController.dispose();
    _startTimeController.dispose();
    super.dispose();
  }

  void _publishSurvey() async {
    String question = _questionController.text.trim();
    List<String> options = _optionControllers.map((controller) => controller.text.trim()).toList();
    int duration = int.tryParse(_durationController.text.trim()) ?? 0;

    if (_selectedStartDate != null && _selectedStartTime != null) {
      final startDateTime = DateTime(
        _selectedStartDate!.year,
        _selectedStartDate!.month,
        _selectedStartDate!.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );

      if (question.isNotEmpty && options.every((option) => option.isNotEmpty) && duration > 0) {
        final expiresAt = startDateTime.add(Duration(minutes: duration));
        final timestamp = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance.collection('surveys').add({
          'question': question,
          'options': options,
          'starts_at': startDateTime.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
          'timestamp': timestamp,
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => PublishedSurveysScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Por favor completa todos los campos')),
        );
      }
    }
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers.removeAt(index).dispose();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedStartTime = picked;
        _startTimeController.text = picked.format(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Encuesta'),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => PublishedSurveysScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  labelText: 'Escribe tu pregunta',
                ),
              ),
              SizedBox(height: 10),
              ..._optionControllers.asMap().entries.map((entry) {
                int index = entry.key;
                TextEditingController controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Opción',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle),
                        onPressed: () => _removeOption(index),
                      ),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addOption,
                child: Text('Agregar Opción'),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Duración en minutos',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _startDateController,
                decoration: InputDecoration(
                  labelText: 'Fecha de inicio',
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _startTimeController,
                decoration: InputDecoration(
                  labelText: 'Hora de inicio',
                ),
                readOnly: true,
                onTap: () => _selectTime(context),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _publishSurvey,
                child: Text('Publicar'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => PublishedSurveysScreen()),
                  );
                },
                child: Text('Inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
