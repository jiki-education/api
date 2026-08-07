class SerializeAdminLevelTranslation
  include Mandate

  initialize_with :translation

  def call
    {
      id: translation.id,
      level_slug: translation.level.slug,
      locale: translation.locale,
      milestone_email_subject: translation.milestone_email_subject,
      milestone_email_content_markdown: translation.milestone_email_content_markdown
    }
  end
end
