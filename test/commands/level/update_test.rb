require "test_helper"

class Level::UpdateTest < ActiveSupport::TestCase
  test "updates level attributes" do
    level = create :level

    updated_level = Level::Update.(level, { milestone_email_subject: "New subject" })

    assert_equal "New subject", updated_level.milestone_email_subject
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
      Level::Update.(level, { slug: "" })
    end
  end

  test "returns updated level" do
    level = create :level

    result = Level::Update.(level, { slug: "updated" })

    assert_instance_of Level, result
    assert_equal level.id, result.id
  end
end
