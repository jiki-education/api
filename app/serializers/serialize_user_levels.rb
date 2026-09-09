class SerializeUserLevels
  include Mandate

  initialize_with :user_levels

  def call
    # Group the single optimized query by level, preserving level position order
    grouped = results.group_by { |row| row[:level_slug] }

    grouped.map do |level_slug, rows|
      {
        level_slug: level_slug,
        status: rows.first[:user_level_completed_at] ? "completed" : "started",
        user_lessons: serialize_lessons(rows)
      }
    end
  end

  private
  # Keyed so the pluck and the hash it becomes can't drift apart.
  PLUCKED_COLUMNS = {
    level_slug: "levels.slug",
    lesson_slug: "lessons.slug",
    user_lesson_id: "user_lessons.id",
    completed_at: "user_lessons.completed_at",
    bonus_completed_at: "user_lessons.bonus_completed_at",
    walkthrough_video_watched_percentage: "user_lessons.walkthrough_video_watched_percentage",
    user_level_completed_at: "user_levels.completed_at"
  }.freeze

  # Each level's rows are ordered by lesson position. We emit every lesson the
  # user has a record for (completed/started), and - provided nothing in the
  # level is currently in progress - the single next lesson as not_started.
  # Lessons beyond that next one are not included.
  def serialize_lessons(rows)
    in_progress = rows.any? { |row| row[:user_lesson_id].present? && row[:completed_at].blank? }

    [].tap do |lessons|
      rows.each do |row|
        if row[:user_lesson_id].present?
          lessons << serialize_lesson(row, row[:completed_at].present? ? "completed" : "started")
        elsif !in_progress && row[:user_level_completed_at].blank?
          # First lesson with no UserLesson record: this is the next lesson up.
          # A completed level never advertises a next lesson.
          lessons << serialize_lesson(row, "not_started")
          break
        else
          break
        end
      end
    end
  end

  def serialize_lesson(row, status)
    {
      lesson_slug: row[:lesson_slug],
      status:,
      bonus_completed: row[:bonus_completed_at].present?,
      walkthrough_video_watched_percentage: row[:walkthrough_video_watched_percentage]
    }
  end

  memoize
  def results
    user_levels.
      joins(:level).
      joins("INNER JOIN lessons ON lessons.level_id = levels.id").
      joins("LEFT JOIN user_lessons ON user_lessons.lesson_id = lessons.id AND user_lessons.user_id = user_levels.user_id").
      order("levels.position, lessons.position").
      pluck(*PLUCKED_COLUMNS.values).
      map { |row| PLUCKED_COLUMNS.keys.zip(row).to_h }
  end
end
