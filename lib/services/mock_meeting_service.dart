/// MockMeetingService — now superseded by MockOpenClawAgent.generateMeetingBrief().
///
/// This service is kept for backward compatibility but meeting brief generation
/// has been moved to MockOpenClawAgent for context-aware AI processing.
///
/// PRODUCTION: This will be replaced by a Gmail API + OAuth flow to
/// read real email threads and extract meeting context automatically.
library;

import '../models/meeting_model.dart';

class MockMeetingService {
  /// Legacy method — returns null since meeting briefs are now user-generated.
  ///
  /// PRODUCTION: This will call Gmail API with OAuth to fetch upcoming meeting emails.
  Future<MeetingModel?> getNextMeeting() async {
    // Meeting briefs are now generated via user input in MeetingAssistantScreen.
    // Use AppStateProvider.generateMeetingBrief() instead.
    return null;
  }
}
