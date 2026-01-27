class SerializeCourses
  include Mandate

  initialize_with :courses

  def call
    courses.map { |course| SerializeCourse.(course) }
  end
end
