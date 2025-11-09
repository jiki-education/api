require "test_helper"

class Level::UpdateTest < ActiveSupport::TestCase
  test "updates level attributes" do
    level = create :level, title: "Old Title", description: "Old description"

    updated_level = Level::Update.(level, { title: "New Title", description: "New description" })

    assert_equal "New Title", updated_level.title
    assert_equal "New description", updated_level.description
    assert_equal level.id, updated_level.id
  end

  test "updates position" do
    level = create :level, position: 1

    updated_level = Level::Update.(level, { position: 5 })

    assert_equal 5, updated_level.position
  end

  test "updates slug" do
    level = create :level, slug: "old-slug"

    updated_level = Level::Update.(level, { slug: "new-slug" })

    assert_equal "new-slug", updated_level.slug
  end

  test "raises error on invalid attributes" do
    level = create :level

    assert_raises ActiveRecord::RecordInvalid do
      Level::Update.(level, { title: "" })
    end
  end

  test "returns updated level" do
    level = create :level

    result = Level::Update.(level, { title: "Updated" })

    assert_instance_of Level, result
    assert_equal level.id, result.id
  end
end
