class Lesson::Update
  include Mandate

  initialize_with :lesson, :attributes

  def call
    lesson.update!(attributes)
    lesson
  end
end
