require "test_helper"

# Tests for the ActiveRecord::Base extensions in config/initializers/active_record.rb
class ActiveRecordExtensionsTest < ActiveSupport::TestCase
  test "find_create_or_find_by! finds existing record" do
    user_lesson = create(:user_lesson)

    result = UserLesson.find_create_or_find_by!(user: user_lesson.user, lesson: user_lesson.lesson)

    assert_equal user_lesson.id, result.id
  end

  test "find_create_or_find_by! creates when missing" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    result = UserLesson.find_create_or_find_by!(user:, lesson:) { |ul| ul.started_at = Time.current }

    assert result.persisted?
    assert result.started_at.present?
  end

  test "find_create_or_find_by! recovers when uniqueness validation loses a race" do
    user_lesson = create(:user_lesson)

    # The row already exists in the DB (the race "winner"); stubbing the
    # first find_by! to miss recreates the loser's view. create! then runs
    # for real and its uniqueness validation sees the committed row, raising
    # RecordInvalid — the exact failure mode from Sentry JIKI-API-M.
    UserLesson.stubs(:find_by!).raises(ActiveRecord::RecordNotFound).then.returns(user_lesson)

    result = nil
    assert_no_difference -> { UserLesson.count } do
      result = UserLesson.find_create_or_find_by!(user: user_lesson.user, lesson: user_lesson.lesson)
    end
    assert_equal user_lesson.id, result.id
  end

  test "find_create_or_find_by! re-raises RecordInvalid for non-uniqueness failures" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    assert_raises(ActiveRecord::RecordInvalid) do
      UserLesson.find_create_or_find_by!(user:, lesson:) { |ul| ul.difficulty_rating = 99 }
    end
  end
end
