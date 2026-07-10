require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds are idempotent, non-destructive and contain no sample data" do
    # First run: creates everything from scratch
    run_seeds!

    course = Course.find_by!(slug: "coding-fundamentals")
    assert_operator course.levels.count, :>, 0
    assert_operator Lesson.count, :>, 0
    assert_operator Concept.count, :>, 0
    assert_operator Challenge.count, :>, 0
    assert_operator Badge.count, :>, 0

    # Snapshot record IDs to prove the second run updates rather than recreates
    level_ids = Level.pluck(:id).sort
    lesson_ids = Lesson.pluck(:id).sort
    concept_ids = Concept.pluck(:id).sort
    challenge_ids = Challenge.pluck(:id).sort
    badge_ids = Badge.pluck(:id).sort

    # Simulate a real production user with progress
    user = create(:user)
    lesson = course.levels.first.lessons.first
    user_lesson = create(:user_lesson, user:, lesson:)
    user_level = UserLevel.find_by!(user:, level: course.levels.first)
    user_course = UserCourse.find_by!(user:, course:)

    # Simulate stale content that should be brought back in line with the seed data
    course.levels.first.update!(title: "Stale Level Title")
    lesson.update!(title: "Stale Lesson Title")
    Badge.first.update!(name: "Stale Badge Name")

    # Second run: must update stale content without deleting or recreating anything
    run_seeds!

    # Same records - nothing recreated
    assert_equal level_ids, Level.pluck(:id).sort
    assert_equal lesson_ids, Lesson.pluck(:id).sort
    assert_equal concept_ids, Concept.pluck(:id).sort
    assert_equal challenge_ids, Challenge.pluck(:id).sort
    assert_equal badge_ids, Badge.pluck(:id).sort

    # User progress survives
    assert UserCourse.exists?(user_course.id)
    assert UserLevel.exists?(user_level.id)
    assert UserLesson.exists?(user_lesson.id)

    # Stale content re-synced
    refute_equal "Stale Level Title", course.levels.first.reload.title
    refute_equal "Stale Lesson Title", lesson.reload.title
    refute_equal "Stale Badge Name", Badge.first.reload.name

    # The admin user exists but is not an admin outside production
    admin_user = User.find_by!(email: "ihid@jiki.io")
    refute admin_user.admin?

    # No development sample data leaks outside development
    refute User.exists?(email: "test@example.com")
    refute Payment.exists?
    refute User::AcquiredBadge.exists?
  end

  private
  def run_seeds!
    # Seeds legitimately run per-record lookups in loops; don't fail on N+1 queries.
    # capture_io silences the seeds' progress output in the test run.
    Prosopite.pause do
      capture_io { Rails.application.load_seed }
    end
  end
end
