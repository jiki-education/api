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
  # Each level's rows are ordered by lesson position. We emit every lesson the
  # user has a record for (completed/started), and - provided nothing in the
  # level is currently in progress - the single next lesson as not_started.
  # Lessons beyond that next one are not included.
  def serialize_lessons(rows)
    blocked = in_progress?(rows)
    advertised_next = false

    [].tap do |lessons|
      rows.each do |row|
        if row[:user_lesson_id].present?
          lessons << serialize_lesson(row, row[:completed_at].present? ? "completed" : "started")
        elsif !blocked && !advertised_next && row[:user_level_completed_at].blank?
          # First lesson with no UserLesson record: this is the next lesson up.
          # A completed level never advertises a next lesson.
          lessons << serialize_lesson(row, "not_started")
          advertised_next = true
        else
          break
        end
      end
    end
  end

  # What actually stops a user starting something else is the level's pointer,
  # which is the condition UserLesson::Start guards on - not the mere existence
  # of an incomplete UserLesson. The two only diverge once a lesson reorder has
  # left an incomplete lesson behind the user's frontier and the pointer has
  # been released from it (see Curriculum::ReleaseStrandedLessonPointers).
  # Treating that released row as "in progress" would hide the lesson the user
  # now owes and leave them with nothing to click.
  def in_progress?(rows)
    current_user_lesson_id = rows.first[:current_user_lesson_id]
    return false if current_user_lesson_id.blank?

    rows.any? do |row|
      row[:user_lesson_id] == current_user_lesson_id && row[:completed_at].blank?
    end
  end

  def serialize_lesson(row, status)
    {
      lesson_slug: row[:lesson_slug],
      status:,
      walkthrough_video_watched_percentage: row[:walkthrough_video_watched_percentage]
    }
  end

  memoize
  def results
    results = user_levels.
      joins(:level).
      joins("INNER JOIN lessons ON lessons.level_id = levels.id").
      joins("LEFT JOIN user_lessons ON user_lessons.lesson_id = lessons.id AND user_lessons.user_id = user_levels.user_id").
      order("levels.position, lessons.position").
      pluck(
        "levels.slug",
        "lessons.slug",
        "user_lessons.id",
        "user_lessons.completed_at",
        "user_lessons.walkthrough_video_watched_percentage",
        "user_levels.completed_at",
        "user_levels.current_user_lesson_id"
      )

    # Map pluck results (arrays) to hashes for easier access
    results.map do |level_slug, lesson_slug, user_lesson_id, lesson_completed_at, watched_percentage, user_level_completed_at,
      current_user_lesson_id|
      {
        level_slug: level_slug,
        lesson_slug: lesson_slug,
        user_lesson_id: user_lesson_id,
        completed_at: lesson_completed_at,
        walkthrough_video_watched_percentage: watched_percentage,
        user_level_completed_at: user_level_completed_at,
        current_user_lesson_id: current_user_lesson_id
      }
    end
  end
end
