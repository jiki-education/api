class Utils::RecordForIdentifier
  include Mandate

  initialize_with :type, :identifier

  def call
    guard!

    klass.find_by!(key => identifier)
  end

  private
  VALID_TYPES = %w[lesson challenge].freeze
  private_constant :VALID_TYPES

  def guard!
    raise InvalidPolymorphicRecordType, "Unsupported context type: #{type}" unless VALID_TYPES.include?(type)
  end

  memoize
  def klass
    case type
    when "lesson", "challenge"
      type.classify.constantize
    end
  end

  memoize
  def key
    case type
    when "lesson", "challenge"
      :slug
    end
  end
end
