class SerializeAdminLessonTranslation
  include Mandate

  initialize_with :translation

  def call
    {
      id: translation.id,
      lesson_slug: translation.lesson.slug,
      locale: translation.locale,
      title: translation.title,
      description: translation.description
    }
  end
end
