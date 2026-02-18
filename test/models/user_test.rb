require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with all attributes" do
    user = build(:user)
    assert user.valid?
  end

  test "invalid without email" do
    user = build(:user, email: nil)
    refute user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with duplicate email" do
    create(:user, email: "test@example.com")
    user = build(:user, email: "test@example.com")
    refute user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "invalid with invalid email format" do
    user = build(:user, email: "invalid-email")
    refute user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "invalid without password" do
    user = build(:user, password: nil)
    refute user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "invalid with short password" do
    user = build(:user, password: "short", password_confirmation: "short")
    refute user.valid?
    assert(user.errors[:password].any? { |msg| msg.include?("is too short") })
  end

  test "authenticates with correct password" do
    password = "testpassword123"
    user = create(:user, password: password)
    assert user.valid_password?(password)
  end

  test "does not authenticate with incorrect password" do
    user = create(:user, password: "correctpassword")
    refute user.valid_password?("wrongpassword")
  end

  test "name is optional" do
    user = build(:user, name: nil)
    assert user.valid?
  end

  test "locale is required" do
    user = build(:user, locale: nil)
    refute user.valid?
    assert_includes user.errors[:locale], "can't be blank"
  end

  test "locale must be en or hu" do
    user = build(:user, locale: "fr")
    refute user.valid?
    assert_includes user.errors[:locale], "is not included in the list"

    user.locale = "en"
    assert user.valid?

    user.locale = "hu"
    assert user.valid?
  end

  test "deleting user cascades to delete user_lessons and user_levels" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise)

    user_level = create(:user_level, user:, level:)
    user_lesson = create(:user_lesson, user:, lesson:)

    user_level_id = user_level.id
    user_lesson_id = user_lesson.id

    user.destroy!

    refute UserLevel.exists?(user_level_id)
    refute UserLesson.exists?(user_lesson_id)
  end

  test "automatically creates data record on user creation" do
    user = create(:user)

    assert user.data.present?
    assert_instance_of User::Data, user.data
    assert user.data.persisted?
  end

  test "data record has empty unlocked_concept_ids by default" do
    user = create(:user)

    assert_empty user.data.unlocked_concept_ids
  end

  test "delegates unknown methods to data record" do
    user = create(:user)

    # Access via delegation
    assert_empty user.unlocked_concept_ids

    # Modify via delegation
    user.data.unlocked_concept_ids << 1
    assert_equal [1], user.unlocked_concept_ids
  end

  test "respond_to? returns true for data record methods" do
    user = create(:user)

    assert_respond_to user, :unlocked_concept_ids
  end

  test "raises NoMethodError for truly unknown methods" do
    user = create(:user)

    assert_raises NoMethodError do
      user.completely_unknown_method
    end
  end

  test "automatically creates activity_data record on user creation" do
    user = create(:user)

    assert user.activity_data.present?
    assert_instance_of User::ActivityData, user.activity_data
    assert user.activity_data.persisted?
  end

  test "activity_data record has default values" do
    user = create(:user)

    assert_empty(user.activity_data.activity_days)
    assert_equal 0, user.activity_data.current_streak
    assert_equal 0, user.activity_data.longest_streak
    assert_equal 0, user.activity_data.total_active_days
  end

  test "current_streak returns value from aggregate_activity_data" do
    user = create(:user)
    user.activity_data.update!(current_streak: 5)

    assert_equal 5, user.current_streak
  end

  test "total_active_days returns value from aggregate_activity_data" do
    user = create(:user)
    user.activity_data.update!(total_active_days: 10)

    assert_equal 10, user.total_active_days
  end

  test "currency returns usd when country_code is nil" do
    user = create(:user)
    assert_nil user.country_code

    assert_equal :usd, user.currency
  end

  test "currency returns usd for US country" do
    user = create(:user)
    user.data.update_column(:country_code, "US")

    assert_equal :usd, user.currency
  end

  test "currency returns inr for India" do
    user = create(:user)
    user.data.update_column(:country_code, "IN")

    assert_equal :inr, user.currency
  end

  test "currency returns gbp for GB" do
    user = create(:user)
    user.data.update_column(:country_code, "GB")

    assert_equal :gbp, user.currency
  end

  test "currency returns eur for EUR countries" do
    user = create(:user)
    user.data.update_column(:country_code, "ES")

    assert_equal :eur, user.currency
  end

  test "currency returns usd for unknown country" do
    user = create(:user)
    user.data.update_column(:country_code, "XX")

    assert_equal :usd, user.currency
  end
end
