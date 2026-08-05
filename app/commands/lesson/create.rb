class Lesson::Create
  include Mandate

  initialize_with :level, :attributes

  def call
    level.lessons.create!(attributes)
  end
end
