class Lesson::Create
  include Mandate

  initialize_with :level, :attributes

  def call
    # Auto-generate slug from title if not provided
    attributes[:slug] ||= attributes[:title]&.parameterize

    level.lessons.create!(attributes)
  end
end
