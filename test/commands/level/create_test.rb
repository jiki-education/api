require "test_helper"

class Level::CreateTest < ActiveSupport::TestCase
  test "creates level with valid attributes" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn the fundamentals of Ruby",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    level = Level::Create.(params)

    assert level.persisted?
    assert_equal "ruby-basics", level.slug
    assert_equal "Ruby Basics", level.title
    assert_equal "Learn the fundamentals of Ruby", level.description
  end

  test "auto-assigns position when not provided" do
    course = create(:course)
    create(:level, course:, position: 1)
    create(:level, course:, position: 2)

    params = {
      course:,
      slug: "new-level",
      title: "New Level",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    level = Level::Create.(params)

    assert_equal 3, level.position
  end

  test "accepts explicit position" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!",
      position: 5
    }

    level = Level::Create.(params)

    assert_equal 5, level.position
  end

  test "raises error when slug is missing" do
    course = create(:course)
    params = {
      course:,
      title: "Ruby Basics",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error when title is missing" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error when description is missing" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      title: "Ruby Basics",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error when slug is blank" do
    course = create(:course)
    params = {
      course:,
      slug: "",
      title: "Ruby Basics",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error when title is blank" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      title: "",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error when description is blank" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error for duplicate slug" do
    create(:level, slug: "ruby-basics")
    course = create(:course)

    params = {
      course:,
      slug: "ruby-basics",
      title: "Another Level",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "raises error for duplicate position within course" do
    course = create(:course)
    create(:level, course:, position: 1)

    params = {
      course:,
      slug: "new-level",
      title: "New Level",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!",
      position: 1
    }

    assert_raises ActiveRecord::RecordInvalid do
      Level::Create.(params)
    end
  end

  test "returns created level" do
    course = create(:course)
    params = {
      course:,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Description",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    result = Level::Create.(params)

    assert_instance_of Level, result
    assert result.persisted?
  end
end
