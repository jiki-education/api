class SerializeLevels
  include Mandate

  initialize_with :levels

  def call
    levels_with_includes.map do |level|
      {
        slug: level.slug,
        lessons: level.lessons.map { |lesson| SerializeLesson.(lesson, nil) }
      }
    end
  end

  def levels_with_includes
    # Include lessons to avoid N+1 queries
    levels.to_active_relation.includes(:lessons)
  end
end
