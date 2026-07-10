require "test_helper"

class Challenge::CreateTest < ActiveSupport::TestCase
  test "creates challenge with valid attributes" do
    attributes = {
      title: "Calculator App",
      description: "Build a calculator application",
      exercise_slug: "calculator"
    }

    challenge = Challenge::Create.(attributes)

    assert_equal "Calculator App", challenge.title
    assert_equal "Build a calculator application", challenge.description
    assert_equal "calculator", challenge.exercise_slug
    assert challenge.persisted?
  end

  test "raises validation error for invalid attributes" do
    attributes = { title: "" }

    assert_raises ActiveRecord::RecordInvalid do
      Challenge::Create.(attributes)
    end
  end
end
