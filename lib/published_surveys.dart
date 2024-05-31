import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:votaciones/main.dart';
import 'create_survey.dart';
import 'survey_history.dart';

void _createSurvey(String question, List<String> options, DateTime startsAt, DateTime expiresAt) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance.collection('surveys').add({
      'question': question,
      'options': options,
      'starts_at': startsAt.toIso8601String(),//x
      'expires_at': expiresAt.toIso8601String(),
      'timestamp': FieldValue.serverTimestamp(),
      'created_by': user.email,
    });
  }
}

class PublishedSurveysScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Encuestas Publicadas'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('surveys').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No hay encuestas publicadas.'));
          }

          // Filtrar encuestas no caducadas
          final now = DateTime.now();
          final validDocs = snapshot.data!.docs.where((doc) {
            var survey = doc.data() as Map<String, dynamic>;
            var expiresAt = DateTime.parse(survey['expires_at']);
            var startsAt = DateTime.parse(survey['starts_at']);//x
            return now.isAfter(startsAt) && expiresAt.isAfter(now);
          }).toList();

          if (validDocs.isEmpty) {
            return Center(child: Text('No hay encuestas disponibles.'));
          }

          return ListView(
            children: validDocs.map((doc) {
              return SurveyTile(doc: doc);
            }).toList(),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "createSurvey",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => CreateSurveyScreen()),
              );
            },
            child: Icon(Icons.add),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "surveyHistory",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SurveyHistoryScreen()),
              );
            },
            child: Icon(Icons.history),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "logout",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => AuthScreen()),
              );
            },
            child: Icon(Icons.exit_to_app),
          ),
        ],
      ),
    );
  }
}

class SurveyTile extends StatefulWidget {
  final QueryDocumentSnapshot doc;

  SurveyTile({required this.doc});

  @override
  _SurveyTileState createState() => _SurveyTileState();
}

class _SurveyTileState extends State<SurveyTile> {
  String? _selectedOption;
  bool _hasVoted = false;
  Timer? _timer;
  DateTime _expiresAt = DateTime.now();
  DateTime _startsAt = DateTime.now();//x
  Duration _timeRemaining = Duration();

  @override
  void initState() {
    super.initState();
    _checkIfUserHasVoted();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkIfUserHasVoted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var survey = widget.doc.data() as Map<String, dynamic>;
      var votes = (survey['votes'] as Map<String, dynamic>?) ?? {};
      if (votes.containsKey(user.uid)) {
        setState(() {
          _selectedOption = votes[user.uid];
          _hasVoted = true;
        });
      }
    }
  }

  void _startTimer() {
    var survey = widget.doc.data() as Map<String, dynamic>;
    _expiresAt = DateTime.parse(survey['expires_at']);
    _startsAt = DateTime.parse(survey['starts_at']);//x
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining = _expiresAt.difference(DateTime.now());
        if (_timeRemaining.isNegative) {
          _timer?.cancel();
        }
      });
    });
  }

  String getTimeRemaining() {
    if (_timeRemaining.isNegative) {
      return 'La encuesta ha caducado.';
    }

    final hours = _timeRemaining.inHours;
    final minutes = _timeRemaining.inMinutes % 60;
    final seconds = _timeRemaining.inSeconds % 60;
    return 'Tiempo restante: $hours horas $minutes minutos $seconds segundos';
  }

  @override
  Widget build(BuildContext context) {
    var survey = widget.doc.data() as Map<String, dynamic>;
    var options = (survey['options'] as List<dynamic>).cast<String>();
    var votes = (survey['votes'] as Map<String, dynamic>?) ?? {};
    var now = DateTime.now();
    var isExpired = now.isAfter(_expiresAt);
    var createdBy = survey['created_by'] ?? '';
    var isAboutToExpire = _expiresAt.difference(now).inMinutes < 10;

    if (isExpired) {
      return SizedBox.shrink(); // No mostrar encuestas caducadas
    }

    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              survey['question'],
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Publicado por: $createdBy',
              style: TextStyle(fontSize: 14.0, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 10),
            ...options.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: _selectedOption,
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value;
                  });
                },
              );
            }).toList(),
            ElevatedButton(
              onPressed: _selectedOption == null
                  ? null
                  : () async {
                      if (_selectedOption != null) {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance.runTransaction((transaction) async {
                            DocumentSnapshot freshSnap = await transaction.get(widget.doc.reference);
                            var freshData = freshSnap.data() as Map<String, dynamic>;
                            var freshVotes = (freshData['votes'] as Map<String, dynamic>?) ?? {};
                            freshVotes[user.uid] = _selectedOption;

                            transaction.update(widget.doc.reference, {'votes': freshVotes});
                          });
                          setState(() {
                            _hasVoted = true;
                          });
                        }
                      }
                    },
              child: Text('Votar'),
            ),
            SizedBox(height: 10),
            Text(
              'Resultados:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: options.map((option) {
                int voteCount = votes.values.where((vote) => vote == option).length;
                return Text('$option: $voteCount votos');
              }).toList(),
            ),
            SizedBox(height: 10),
            Text(
              getTimeRemaining(),
              style: TextStyle(color: isAboutToExpire ? Colors.red : Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
