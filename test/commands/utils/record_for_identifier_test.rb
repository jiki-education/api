require "test_helper"

class Utils::RecordForIdentifierTest < ActiveSupport::TestCase
  test "finds lesson by slug" do
    lesson = create(:lesson, :exercise, slug: "basic-movement")

    result = Utils::RecordForIdentifier.("lesson", "basic-movement")

    assert_equal lesson, result
  end

  test "finds project by slug" do
    project = create(:project, slug: "calculator-app")

    result = Utils::RecordForIdentifier.("project", "calculator-app")

    assert_equal project, result
  end

  test "raises ActiveRecord::RecordNotFound when lesson not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Utils::RecordForIdentifier.("lesson", "non-existent-slug")
    end
  end

  test "raises ActiveRecord::RecordNotFound when project not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Utils::RecordForIdentifier.("project", "non-existent-slug")
    end
  end

  test "raises error for unsupported context type" do
    error = assert_raises(InvalidPolymorphicRecordType) do
      Utils::RecordForIdentifier.("concept", "some-identifier")
    end

    assert_match(/Unsupported context type: concept/, error.message)
  end

  test "raises error for unknown context type" do
    error = assert_raises(InvalidPolymorphicRecordType) do
      Utils::RecordForIdentifier.("unknown", "some-identifier")
    end

    assert_match(/Unsupported context type: unknown/, error.message)
  end
end
