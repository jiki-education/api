class Utils::RecordForIdentifier
  include Mandate

  initialize_with :type, :identifier

  def call
    guard!

    klass.find_by!(key => identifier)
  end

  private
  # LEGACY: "project" is the pre-rename name for "challenge". Delete it
  # once the front end has been deployed.
  VALID_TYPES = %w[lesson challenge project].freeze
  private_constant :VALID_TYPES

  def guard!
    raise InvalidPolymorphicRecordType, "Unsupported context type: #{type}" unless VALID_TYPES.include?(type)
  end

  memoize
  def klass
    case type
    when "lesson", "challenge"
      type.classify.constantize
    when "project" # LEGACY: pre-rename name
      Challenge
    end
  end

  memoize
  def key
    case type
    when "lesson", "challenge", "project"
      :slug
    end
  end
end
