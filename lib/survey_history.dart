import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de encuestas participadas'),
      ),
      body: FutureBuilder(
        future: _getParticipatedSurveys(),
        builder: (context, AsyncSnapshot<List<QueryDocumentSnapshot>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No has participado en ninguna encuesta.'));
          }

          return ListView(
            children: snapshot.data!.map((doc) {
              var survey = doc.data() as Map<String, dynamic>;
              return SurveyHistoryTile(doc: doc);
            }).toList(),
          );
        },
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _getParticipatedSurveys() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    final querySnapshot = await FirebaseFirestore.instance.collection('surveys').get();
    final participatedSurveys = querySnapshot.docs.where((doc) {
      var survey = doc.data() as Map<String, dynamic>;
      var votes = (survey['votes'] as Map<String, dynamic>?) ?? {};
      return votes.containsKey(user.uid);
    }).toList();

    return participatedSurveys;
  }
}

class SurveyHistoryTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  SurveyHistoryTile({required this.doc});

  void _showWinnerDialog(BuildContext context) {
    var survey = doc.data() as Map<String, dynamic>;
    var votes = (survey['votes'] as Map<String, dynamic>?) ?? {};
    var options = (survey['options'] as List<dynamic>).cast<String>();

    // Contar votos para cada opción
    Map<String, int> voteCounts = {};
    options.forEach((option) {
      voteCounts[option] = votes.values.where((vote) => vote == option).length;
    });

    // Encontrar la opción con más votos
    var winner = voteCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Encuesta Ganadora'),
          content: Text('La opción ganadora es: $winner'),
          actions: [
            TextButton(
              child: Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String getTimeRemaining(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.isNegative) {
      return 'La encuesta ha caducado.';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    return 'Tiempo restante: $hours horas $minutes minutos';
  }

  @override
  Widget build(BuildContext context) {
    var survey = doc.data() as Map<String, dynamic>;
    var options = (survey['options'] as List<dynamic>).cast<String>();
    var votes = (survey['votes'] as Map<String, dynamic>?) ?? {};
    var expiresAt = DateTime.parse(survey['expires_at']);
    var now = DateTime.now();
    var isExpired = now.isAfter(expiresAt);

    return GestureDetector(
      onTap: () {
        if (isExpired) {
          _showWinnerDialog(context);
        }
      },
      child: Card(
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
              if (isExpired) ...[
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
              ] else ...[
                Text(
                  getTimeRemaining(expiresAt),
                  style: TextStyle(color: isExpired ? Colors.red : Colors.black),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

