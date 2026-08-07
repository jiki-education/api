require "test_helper"

class Challenge::UpdateTest < ActiveSupport::TestCase
  test "updates challenge with valid attributes" do
    challenge = create :challenge

    Challenge::Update.(challenge, { exercise_slug: "updated" })

    assert_equal "updated", challenge.exercise_slug
  end

  test "raises validation error for invalid attributes" do
    challenge = create :challenge

    assert_raises ActiveRecord::RecordInvalid do
      Challenge::Update.(challenge, { slug: "" })
    end
  end

  test "returns the updated challenge" do
    challenge = create :challenge

    result = Challenge::Update.(challenge, { slug: "new-slug" })

    assert_equal challenge, result
    assert_equal "new-slug", result.slug
  end
end
