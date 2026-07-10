require "test_helper"

class Challenge::UpdateTest < ActiveSupport::TestCase
  test "updates challenge with valid attributes" do
    challenge = create :challenge, title: "Original"

    Challenge::Update.(challenge, { title: "Updated" })

    assert_equal "Updated", challenge.title
  end

  test "raises validation error for invalid attributes" do
    challenge = create :challenge

    assert_raises ActiveRecord::RecordInvalid do
      Challenge::Update.(challenge, { title: "" })
    end
  end

  test "returns the updated challenge" do
    challenge = create :challenge

    result = Challenge::Update.(challenge, { title: "New Title" })

    assert_equal challenge, result
    assert_equal "New Title", result.title
  end
end
