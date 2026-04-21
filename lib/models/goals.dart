class Goals {
  List<String> focusBodyParts;
  List<String> tags;
  int routineDuration;

  Goals({
    this.focusBodyParts = const [],
    this.tags = const [],
    this.routineDuration = 30,
  });

  Map<String, dynamic> toJson() => {
    "focus_body_parts": focusBodyParts,
    "tags": tags,
    "routine_duration": routineDuration,
  };
}
