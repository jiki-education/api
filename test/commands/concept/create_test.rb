require "test_helper"

class Concept::CreateTest < ActiveSupport::TestCase
  test "creates concept with valid attributes" do
    attributes = {
      title: "Strings",
      description: "Learn about strings"
    }

    concept = Concept::Create.(attributes)

    assert_equal "Strings", concept.title
    assert_equal "Learn about strings", concept.description
    assert concept.persisted?
  end

  test "raises validation error for invalid attributes" do
    attributes = { title: "" }

    assert_raises ActiveRecord::RecordInvalid do
      Concept::Create.(attributes)
    end
  end
end
