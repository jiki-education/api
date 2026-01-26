class SerializeCourse
  include Mandate

  initialize_with :course

  def call
    {
      slug: course.slug,
      title: course.title,
      description: course.description
    }
  end
end
