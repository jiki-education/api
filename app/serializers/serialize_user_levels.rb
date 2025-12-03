class SerializeUserLevels
  include Mandate

  initialize_with :user_levels

  def call
    # Group data from single optimized query by level
    grouped = results.group_by { |row| row[:level_slug] }

    # Serialize each level with its lessons
    grouped.map do |level_slug, rows|
      # Get the user_level completion status from the first row (same for all lessons in level)
      first_row = rows.first
      {
        level_slug: level_slug,
        completed_at: first_row[:user_level_completed_at],
        user_lessons: rows.map do |row|
          {
            lesson_slug: row[:lesson_slug],
            status: row[:completed_at].present? ? "completed" : "started"
          }
        end
      }
    end
  end

  private
  memoize
  def results
    results = user_levels.
      joins(:level).
      joins(level: { lessons: :user_lessons }).
      where("user_lessons.user_id = user_levels.user_id").
      order("levels.position, lessons.position").
      pluck(
        "levels.slug",
        "lessons.slug",
        "user_lessons.completed_at",
        "user_levels.completed_at"
      )

    # Map pluck results (arrays) to hashes for easier access
    results.map do |level_slug, lesson_slug, lesson_completed_at, user_level_completed_at|
      {
        level_slug: level_slug,
        lesson_slug: lesson_slug,
        completed_at: lesson_completed_at,
        user_level_completed_at: user_level_completed_at
      }
    end
  end
end
