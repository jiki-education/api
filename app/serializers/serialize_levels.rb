class SerializeLevels
  include Mandate

  initialize_with :levels

  def call
    levels_with_includes.map do |level|
      {
        slug: level.slug,
        milestone_summary: milestone_summaries[level.id],
        lessons: level.lessons.map { |lesson| { slug: lesson.slug, type: lesson.type } }
      }
    end
  end

  def levels_with_includes
    # Include lessons and translations to avoid N+1 queries
    # translations.find_by will use the preloaded association
    levels.to_active_relation.includes(:lessons)
  end

  memoize
  def milestone_summaries
    return levels_with_includes.map { |l| [l.id, l.milestone_summary] }.to_h if I18n.locale.to_s == "en"

    Level::Translation.where(locale: I18n.locale, level: levels_with_includes).
      pluck(:level_id, :milestone_summary).
      to_h
  end
end
