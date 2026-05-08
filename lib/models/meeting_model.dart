class MeetingModel {
  String title;
  DateTime time;
  String location;
  String relatedFile;
  String summary;
  List<String> talkingPoints;
  List<String> questionsToExpect;
  int confidenceScore; // 0 to 100
  int preparationScore; // 0 to 100

  // Raw user input text for AI processing
  String inputText;

  MeetingModel({
    required this.title,
    required this.time,
    required this.location,
    required this.relatedFile,
    this.summary = '',
    this.talkingPoints = const [],
    this.questionsToExpect = const [],
    this.confidenceScore = 0,
    this.preparationScore = 0,
    this.inputText = '',
  });
}
