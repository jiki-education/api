require "test_helper"

class ConceptTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:concept).valid?
  end

  test "requires slug" do
    refute build(:concept, slug: nil).valid?
  end

  test "requires unique slug" do
    create(:concept, slug: "strings")
    duplicate = build(:concept, slug: "strings")
    refute duplicate.valid?
  end

  test "to_param returns slug" do
    concept = create(:concept, slug: "strings")
    assert_equal "strings", concept.to_param
  end
end
