require "test_helper"

class Challenge::CreateTest < ActiveSupport::TestCase
  test "creates challenge with valid attributes" do
    challenge = Challenge::Create.({ slug: "calculator", exercise_slug: "calculator" })

    assert_equal "calculator", challenge.slug
    assert_equal "calculator", challenge.exercise_slug
    assert challenge.persisted?
  end

  test "raises validation error for invalid attributes" do
    assert_raises ActiveRecord::RecordInvalid do
      Challenge::Create.({ slug: "" })
    end
  end
end
