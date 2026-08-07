require "test_helper"

class Level::CreateTest < ActiveSupport::TestCase
  test "creates level with valid attributes" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      milestone_email_subject: "Nice one!",
      milestone_email_content_markdown: "You finished it."
    }

    level = Level::Create.(params)

    assert level.persisted?
    assert_equal "ruby-basics", level.slug
  end

  test "auto-assigns position when not provided" do
    course = create(:course)
    create(:level, course:, position: 1)
    create(:level, course:, position: 2)

    level = Level::Create.({ course:, slug: "new-level" })

    assert_equal 3, level.position
  end

  test "accepts explicit position" do
    course = create(:course)

    level = Level::Create.({ course:, slug: "ruby-basics", position: 5 })

    assert_equal 5, level.position
  end

  test "raises error when slug is missing" do
    course = create(:course)

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.({ course: })
    end
  end

  test "raises error when slug is blank" do
    course = create(:course)

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.({ course:, slug: "" })
    end
  end

  test "raises error when slug is duplicated" do
    course = create(:course)
    create(:level, course:, slug: "ruby-basics")

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.({ course:, slug: "ruby-basics" })
    end
  end
end
