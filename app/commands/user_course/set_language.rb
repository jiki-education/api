class UserCourse::SetLanguage
  include Mandate

  initialize_with :user_course, :language

  def call
    raise LanguageAlreadyChosenError, "Language has already been chosen" if user_course.language_chosen?
    raise InvalidLanguageError, "Invalid language" unless UserCourse::SUPPORTED_LANGUAGES.include?(language)

    user_course.update!(language:)
  end
end
