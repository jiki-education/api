class InvalidJsonError < RuntimeError; end

class DuplicateFilenameError < RuntimeError
  attr_reader :filenames

  def initialize(filenames)
    @filenames = filenames
    super("Duplicate filenames: #{filenames.join(', ')}")
  end
end

class FileTooLargeError < RuntimeError
  attr_reader :filename, :max_bytes

  def initialize(filename, max_bytes)
    @filename = filename
    @max_bytes = max_bytes
    super("File '#{filename}' is too large (maximum #{max_bytes} bytes)")
  end
end

class TooManyFilesError < RuntimeError
  attr_reader :count, :max

  def initialize(count, max)
    @count = count
    @max = max
    super("Too many files (maximum #{max})")
  end
end

class InvalidSubmissionError < RuntimeError
  attr_reader :reason

  def initialize(reason)
    @reason = reason
    super(reason.to_s.tr("_", " "))
  end
end

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
  attr_reader :decline_code, :interval, :currency

  def initialize(decline_code: nil, interval: nil, currency: nil)
    @decline_code = decline_code
    @interval = interval
    @currency = currency
    super(decline_code || "Checkout session is not complete")
  end
end
