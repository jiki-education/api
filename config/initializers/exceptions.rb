class InvalidJsonError < RuntimeError; end
class DuplicateFilenameError < RuntimeError; end
class FileTooLargeError < RuntimeError; end
class TooManyFilesError < RuntimeError; end
class InvalidSubmissionError < RuntimeError; end
class InvalidHMACSignatureError < RuntimeError; end
class InvalidSNSSignatureError < RuntimeError; end
class InvalidPolymorphicRecordType < RuntimeError; end
class InvalidUnsubscribeTokenError < RuntimeError; end

# Image upload errors
class ImageFileTooLargeError < RuntimeError; end
class InvalidImageTypeError < RuntimeError; end

# Avatar upload errors
class InvalidAvatarError < RuntimeError; end
class AvatarTooLargeError < RuntimeError; end

# Gemini API errors
module Gemini
  class Error < RuntimeError; end
  class RateLimitError < Error; end
  class InvalidRequestError < Error; end
  class APIError < Error; end
end

# Google OAuth errors
class InvalidGoogleTokenError < RuntimeError; end

# Exercism OAuth errors
class InvalidExercismTokenError < RuntimeError; end

# Exercism server-to-server / webhook errors
class FetchExercismUserStatusesError < RuntimeError; end
class InvalidExercismWebhookSignatureError < RuntimeError; end

# Shared OAuth errors
class InvalidOauthPayloadError < RuntimeError; end

# User progression errors
class UserCourseNotFoundError < RuntimeError; end
class LanguageAlreadyChosenError < RuntimeError; end
class InvalidLanguageError < RuntimeError; end
class UserLevelNotFoundError < RuntimeError; end
class UserLessonNotFoundError < RuntimeError; end
class LessonInProgressError < RuntimeError; end
class LessonNotUnlockedError < RuntimeError; end
class LevelNotCompletedError < RuntimeError; end
class ChallengeLockedError < RuntimeError; end

# Badge errors
class BadgeCriteriaNotFulfilledError < RuntimeError; end

# Settings errors
class InvalidNotificationSlugError < RuntimeError; end
class InvalidBooleanError < RuntimeError; end

# Assistant conversation errors
class AssistantConversationAccessDeniedError < RuntimeError; end

# Stripe errors
class StripeSubscriptionCancellationError < RuntimeError; end

# Mailshot errors
class MailshotUnknownSegmentError < RuntimeError; end
class MailshotBlankBodyError < RuntimeError; end

class StripeCheckoutSessionIncompleteError < RuntimeError
  attr_reader :decline_reason, :interval, :currency

  def initialize(decline_reason: nil, interval: nil, currency: nil)
    @decline_reason = decline_reason
    @interval = interval
    @currency = currency
    super(decline_reason || "Checkout session is not complete")
  end
end
