require "test_helper"

class ChallengeTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:challenge).valid?
  end

  test "requires title" do
    challenge = build(:challenge, title: nil)
    refute challenge.valid?
  end

  test "requires description" do
    challenge = build(:challenge, description: nil)
    refute challenge.valid?
  end

  test "requires exercise_slug" do
    challenge = build(:challenge, exercise_slug: nil)
    refute challenge.valid?
  end

  test "requires unique slug" do
    create(:challenge, slug: "calculator")
    duplicate = build(:challenge, slug: "calculator")
    refute duplicate.valid?
  end

  test "auto-generates slug from title on create" do
    challenge = create(:challenge, title: "Todo App", slug: nil)
    assert_equal "todo-app", challenge.slug
  end

  test "preserves provided slug" do
    challenge = create(:challenge, title: "Todo App", slug: "custom-slug")
    assert_equal "custom-slug", challenge.slug
  end

  test "to_param returns slug" do
    challenge = create(:challenge, slug: "calculator")
    assert_equal "calculator", challenge.to_param
  end

  test "does not auto-regenerate slug when title changes" do
    challenge = create(:challenge, title: "Original Title", slug: "custom-slug")

    challenge.update!(title: "Completely Different Title")

    assert_equal "custom-slug", challenge.reload.slug
    refute_equal "completely-different-title", challenge.slug
  end

  test "can be unlocked by a lesson" do
    lesson = create(:lesson, :exercise)
    challenge = create(:challenge, unlocked_by_lesson: lesson)
    assert_equal lesson, challenge.unlocked_by_lesson
  end

  test "has many user_challenges" do
    challenge = create(:challenge)
    user1 = create(:user)
    user2 = create(:user)

    create(:user_challenge, challenge: challenge, user: user1)
    create(:user_challenge, challenge: challenge, user: user2)

    assert_equal 2, challenge.user_challenges.count
  end

  test "has many users through user_challenges" do
    challenge = create(:challenge)
    user1 = create(:user)
    user2 = create(:user)

    create(:user_challenge, challenge: challenge, user: user1)
    create(:user_challenge, challenge: challenge, user: user2)

    assert_equal 2, challenge.users.count
    assert_includes challenge.users, user1
    assert_includes challenge.users, user2
  end
end
