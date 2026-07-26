class MigrateUsersBackToMultipleFunctions < ActiveRecord::Migration[8.1]
  # The `pangram` exercise was moved to the end of `multiple-functions` (from
  # the start of `methods-and-properties`). Some users had already "completed"
  # `multiple-functions` and been advanced onto `methods-and-properties` as
  # their active level without starting anything there, so their now-incomplete
  # `multiple-functions` level (it has the unfinished `pangram` on it) is
  # unreachable to them.
  #
  # Pull those users back onto `multiple-functions` as their active level so
  # `pangram` becomes their frontier: un-complete the level and repoint the
  # course's current level at it. Users who have already engaged past the
  # parked state — started `pangram`, or started any `methods-and-properties`
  # exercise — are left untouched.
  def up
    mf = Level.find_by(slug: "multiple-functions")
    mp = Level.find_by(slug: "methods-and-properties")
    return unless mf && mp

    pangram = Lesson.find_by(slug: "pangram")
    mp_exercise_lesson_ids = mp.lessons.where(type: "exercise").pluck(:id)

    UserCourse.joins(:current_user_level).
      where(user_levels: { level_id: mp.id }).
      find_each do |user_course|
      user_id = user_course.user_id

      # Only users who actually finished multiple-functions.
      mf_user_level = UserLevel.find_by(user_id:, level_id: mf.id)
      next unless mf_user_level&.completed_at

      # Skip anyone who has already engaged past the parked state.
      next if pangram && UserLesson.exists?(user_id:, lesson_id: pangram.id)
      next if mp_exercise_lesson_ids.any? && UserLesson.exists?(user_id:, lesson_id: mp_exercise_lesson_ids)

      transaction do
        mf_user_level.update!(completed_at: nil, current_user_lesson: nil)
        user_course.update!(current_user_level: mf_user_level)
      end
    end
  end

  def down
    # One-off correction of specific users' active-level pointers. The prior
    # (broken) state carries no value and can't be reliably distinguished from
    # legitimate state, so there is nothing safe to reverse.
  end
end
