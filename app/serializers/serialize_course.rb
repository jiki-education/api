class SerializeCourse
  include Mandate

  initialize_with :course

  def call
    {
      slug: course.slug
    }
  end
end
