class Reminder {
  final int? id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String category;
  final bool isCompleted;
  final bool isRecurring;
  final String? recurringType; // 'daily', 'weekly', 'monthly', 'yearly'
  final int priority; // 1=low, 2=medium, 3=high
  final DateTime createdAt;
  final DateTime? completedAt;

  Reminder({
    this.id,
    required this.title,
    this.description,
    required this.dateTime,
    required this.category,
    this.isCompleted = false,
    this.isRecurring = false,
    this.recurringType,
    this.priority = 2,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'category': category,
      'isCompleted': isCompleted ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringType': recurringType,
      'priority': priority,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      category: map['category'],
      isCompleted: map['isCompleted'] == 1,
      isRecurring: map['isRecurring'] == 1,
      recurringType: map['recurringType'],
      priority: map['priority'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt:
          map['completedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
              : null,
    );
  }

  Reminder copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? category,
    bool? isCompleted,
    bool? isRecurring,
    String? recurringType,
    int? priority,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
