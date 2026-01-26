class InvalidJsonError < RuntimeError; end
class DuplicateFilenameError < RuntimeError; end
class FileTooLargeError < RuntimeError; end
class TooManyFilesError < RuntimeError; end
class InvalidSubmissionError < RuntimeError; end
class VideoProductionBadInputsError < RuntimeError; end
class InvalidHMACSignatureError < RuntimeError; end
class InvalidSNSSignatureError < RuntimeError; end
class InvalidPolymorphicRecordType < RuntimeError; end
class InvalidUnsubscribeTokenError < RuntimeError; end

# Image upload errors
class ImageFileTooLargeError < RuntimeError; end
class InvalidImageTypeError < RuntimeError; end

# Gemini API errors
module Gemini
  class Error < RuntimeError; end
  class RateLimitError < Error; end
  class InvalidRequestError < Error; end
  class APIError < Error; end
end

# Google OAuth errors
class InvalidGoogleTokenError < RuntimeError; end

# User progression errors
class UserCourseNotFoundError < RuntimeError; end
class UserLevelNotFoundError < RuntimeError; end
class UserLessonNotFoundError < RuntimeError; end
class LessonInProgressError < RuntimeError; end
class LevelNotCompletedError < RuntimeError; end
class LessonIncompleteError < RuntimeError; end

# Badge errors
class BadgeCriteriaNotFulfilledError < RuntimeError; end

# Settings errors
class InvalidNotificationSlugError < RuntimeError; end

# Assistant conversation errors
class AssistantConversationAccessDeniedError < RuntimeError; end
