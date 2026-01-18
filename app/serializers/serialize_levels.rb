class SerializeLevels
  include Mandate

  initialize_with :levels

  def call
    levels_with_includes.map do |level|
      {
        slug: level.slug,
        milestone_summary: milestone_summaries[level.id],
        lessons: level.lessons.map { |lesson| SerializeLesson.(lesson, content: lesson_contents[lesson.id], include_data: false) }
      }
    end
  end

  def levels_with_includes
    # Include lessons to avoid N+1 queries
    levels.to_active_relation.includes(:lessons)
  end

  memoize
  def milestone_summaries
    return levels_with_includes.map { |l| [l.id, l.milestone_summary] }.to_h if I18n.locale.to_s == "en"

    Level::Translation.where(locale: I18n.locale, level: levels_with_includes).
      pluck(:level_id, :milestone_summary).
      to_h
  end

  memoize
  def lesson_contents
    lessons = levels_with_includes.flat_map(&:lessons)

    # Build English content hash (used directly for :en, or as fallback)
    english_content = lessons.to_h { |l| [l.id, { title: l.title, description: l.description }] }

    return english_content if I18n.locale.to_s == "en"

    # Get translations, merge with English fallback
    translated = Lesson::Translation.where(locale: I18n.locale, lesson: lessons).
      pluck(:lesson_id, :title, :description).
      to_h { |id, title, desc| [id, { title: title, description: desc }] }

    english_content.merge(translated)
  end
end
