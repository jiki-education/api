require "test_helper"

class Concept::UpdateTest < ActiveSupport::TestCase
  test "updates concept with valid attributes" do
    concept = create :concept

    Concept::Update.(concept, { slug: "updated" })

    assert_equal "updated", concept.slug
  end

  test "raises validation error for invalid attributes" do
    concept = create :concept

    assert_raises ActiveRecord::RecordInvalid do
      Concept::Update.(concept, { slug: "" })
    end
  end

  test "returns the updated concept" do
    concept = create :concept

    result = Concept::Update.(concept, { slug: "new-slug" })

    assert_equal concept, result
    assert_equal "new-slug", result.slug
  end
end
