class SerializeAdminLessons
  include Mandate

  initialize_with :lessons

  def call
    lessons.map { |lesson| SerializeAdminLesson.(lesson) }
  end
end
