class SerializeAdminLevelTranslation
  include Mandate

  initialize_with :translation

  def call
    {
      id: translation.id,
      level_slug: translation.level.slug,
      locale: translation.locale,
      title: translation.title,
      description: translation.description,
      milestone_summary: translation.milestone_summary,
      milestone_content: translation.milestone_content
    }
  end
end
