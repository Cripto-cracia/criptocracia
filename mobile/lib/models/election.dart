class Election {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final List<Candidate> candidates;
  final String status;
  final String rsaPubKey;
  
  Election({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.candidates,
    required this.status,
    required this.rsaPubKey,
  });
  
  factory Election.fromJson(Map<String, dynamic> json) {
    // Validate status
    final rawStatus = json['status'] as String? ?? 'open';
    final validStatuses = ['open', 'in-progress', 'finished', 'canceled'];
    final status = validStatuses.contains(rawStatus.toLowerCase()) 
        ? rawStatus.toLowerCase() 
        : 'open';
    
    return Election(
      id: json['id'],
      name: json['name'],
      startTime: DateTime.fromMillisecondsSinceEpoch(json['start_time'] * 1000),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['end_time'] * 1000),
      candidates: (json['candidates'] as List)
          .map((c) => Candidate.fromJson(c))
          .toList(),
      status: status,
      rsaPubKey: json['rsa_pub_key'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime.millisecondsSinceEpoch ~/ 1000,
      'end_time': endTime.millisecondsSinceEpoch ~/ 1000,
      'candidates': candidates.map((c) => c.toJson()).toList(),
      'status': status,
      'rsa_pub_key': rsaPubKey,
    };
  }
}

class Candidate {
  final int id;
  final String name;
  int votes;
  
  Candidate({
    required this.id,
    required this.name,
    this.votes = 0,
  });
  
  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: json['id'],
      name: json['name'],
      votes: json['votes'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'votes': votes,
    };
  }
}