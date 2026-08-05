require "test_helper"

class Concept::CreateTest < ActiveSupport::TestCase
  test "creates concept with valid attributes" do
    concept = Concept::Create.({ slug: "strings" })

    assert_equal "strings", concept.slug
    assert concept.persisted?
  end

  test "raises validation error for invalid attributes" do
    assert_raises ActiveRecord::RecordInvalid do
      Concept::Create.({ slug: "" })
    end
  end
end
