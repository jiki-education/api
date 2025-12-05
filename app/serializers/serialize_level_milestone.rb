class SerializeLevelMilestone
  include Mandate

  initialize_with :level, :locale

  def call
    content = level.content_for_locale(locale)

    {
      level_slug: level.slug,
      locale:,
      title: content[:title],
      description: content[:description],
      milestone_summary: content[:milestone_summary],
      milestone_content: content[:milestone_content]
    }
  end
end
