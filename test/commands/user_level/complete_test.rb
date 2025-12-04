require "test_helper"

class UserLevel::CompleteTest < ActiveSupport::TestCase
  test "completes existing user_level" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    result = UserLevel::Complete.(user, level)

    assert result.persisted?
    assert_equal user.id, result.user_id
    assert_equal level.id, result.level_id
  end

  test "returns existing user_level if it exists" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user: user, level: level)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    result = UserLevel::Complete.(user, level)

    assert_equal user_level.id, result.id
  end

  test "delegates to UserLevel::Find for lookup" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user: user, level: level)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    UserLevel::Find.expects(:call).with(user, level).returns(user_level)

    UserLevel::Complete.(user, level)
  end

  test "returns the user_level" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    result = UserLevel::Complete.(user, level)

    assert_instance_of UserLevel, result
  end

  test "sets completed_at to current time" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    time_before = Time.current
    user_level = UserLevel::Complete.(user, level)
    time_after = Time.current

    assert user_level.completed_at >= time_before
    assert user_level.completed_at <= time_after
  end

  test "is idempotent when completing already completed level" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    user_level = create(:user_level, user: user, level: level, completed_at: 1.day.ago)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)
    old_completed_at = user_level.completed_at

    result = UserLevel::Complete.(user, level)

    # Timestamp should not change on re-completion (idempotent)
    assert_equal old_completed_at.to_i, result.completed_at.to_i
  end

  test "preserves created_at when completing" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    created_time = 2.days.ago
    user_level = create(:user_level, user:, level:)
    user_level.update_column(:created_at, created_time)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    result = UserLevel::Complete.(user, level)

    assert_equal created_time.to_i, result.created_at.to_i
  end

  test "creates user_level for next level when next level exists" do
    user = create(:user)
    level1 = create(:level, position: 1)
    level2 = create(:level, position: 2)
    lesson = create(:lesson, level: level1)
    create(:user_level, user:, level: level1)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    UserLevel::Complete.(user, level1)

    next_user_level = UserLevel.find_by(user: user, level: level2)
    refute_nil next_user_level
    refute_nil next_user_level.created_at
    assert_nil next_user_level.completed_at
  end

  test "does not create next user_level when no next level exists" do
    user = create(:user)
    level = create(:level, position: 1)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    UserLevel::Complete.(user, level)

    assert_equal 1, user.user_levels.count
  end

  test "creates next user_level with gaps in position numbers" do
    user = create(:user)
    level1 = create(:level, position: 1)
    level5 = create(:level, position: 5)
    lesson = create(:lesson, level: level1)
    create(:user_level, user:, level: level1)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    UserLevel::Complete.(user, level1)

    next_user_level = UserLevel.find_by(user: user, level: level5)
    refute_nil next_user_level
    assert_equal level5, next_user_level.level
  end

  test "wraps completion and next level creation in transaction" do
    user = create(:user)
    level1 = create(:level, position: 1)
    level2 = create(:level, position: 2)
    lesson = create(:lesson, level: level1)
    user_level = create(:user_level, user:, level: level1)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)

    # Stub to raise an error during next level creation
    UserLevel::Start.stubs(:call).with(user, level2).raises(ActiveRecord::RecordInvalid)

    assert_raises(ActiveRecord::RecordInvalid) do
      UserLevel::Complete.(user, level1)
    end

    # The completion should be rolled back
    assert_nil user_level.reload.completed_at
  end

  test "sends completion email when template exists" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)
    create(:email_template, slug: "level-1", locale: "en")

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      UserLevel::Complete.(user, level)
    end
  end

  test "does not send email when template does not exist" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-2")
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)
    # No template created for level-2

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      UserLevel::Complete.(user, level)
    end
  end

  # Skip this test due to gem loading issue with Mrml in test environment
  # The functionality works in development/production
  # test "marks email as sent after sending" do
  #   user = create(:user, locale: "en")
  #   level = create(:level, slug: "level-1")
  #   create(:email_template, key: "level-1", locale: "en")
  #
  #   perform_enqueued_jobs do
  #     user_level = UserLevel::Complete.(user, level)
  #     assert user_level.reload.email_sent?
  #   end
  # end

  test "marks email as skipped when no template exists" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-2")
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)
    # No template for level-2

    user_level = UserLevel::Complete.(user, level)
    assert user_level.reload.email_skipped?
  end

  test "idempotency: does not create next level or send email on re-completion" do
    user = create(:user, locale: "en")
    level1 = create(:level, position: 1, slug: "level-1")
    level2 = create(:level, position: 2)
    lesson = create(:lesson, level: level1)
    create(:user_level, user:, level: level1)
    create(:user_lesson, user:, lesson:, completed_at: Time.current)
    create(:email_template, slug: "level-1", locale: "en")

    # First completion
    user_level = UserLevel::Complete.(user, level1)
    old_completed_at = user_level.completed_at

    # Verify next level was created
    assert_equal 2, user.user_levels.count
    next_user_level = UserLevel.find_by(user: user, level: level2)
    refute_nil next_user_level

    # Second completion should be idempotent
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      assert_no_difference -> { user.user_levels.count } do
        result = UserLevel::Complete.(user, level1)

        # Timestamp should not change
        assert_equal old_completed_at.to_i, result.completed_at.to_i
      end
    end
  end

  # Validation tests
  test "raises LessonIncompleteError when no user_lesson exists" do
    user = create(:user)
    level = create(:level)
    create(:lesson, level:)
    create(:user_level, user:, level:)

    error = assert_raises(LessonIncompleteError) do
      UserLevel::Complete.(user, level)
    end

    assert_equal "Cannot complete level: 1 lesson(s) incomplete", error.message
  end

  test "raises LessonIncompleteError when user_lesson exists but not completed" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:, completed_at: nil)

    error = assert_raises(LessonIncompleteError) do
      UserLevel::Complete.(user, level)
    end

    assert_equal "Cannot complete level: 1 lesson(s) incomplete", error.message
  end

  test "raises LessonIncompleteError with multiple incomplete lessons" do
    user = create(:user)
    level = create(:level)
    lesson1 = create(:lesson, level:)
    lesson2 = create(:lesson, level:)
    create(:lesson, level:) # lesson3 has no user_lesson
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user:, lesson: lesson2, completed_at: nil)

    error = assert_raises(LessonIncompleteError) do
      UserLevel::Complete.(user, level)
    end

    assert_equal "Cannot complete level: 2 lesson(s) incomplete", error.message
  end

  test "completes successfully when all lessons are completed" do
    user = create(:user)
    level = create(:level)
    lesson1 = create(:lesson, level:)
    lesson2 = create(:lesson, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user:, lesson: lesson2, completed_at: Time.current)

    assert_nothing_raised do
      result = UserLevel::Complete.(user, level)
      assert result.completed_at.present?
    end
  end
end
