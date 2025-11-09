require "test_helper"

class Project::CreateTest < ActiveSupport::TestCase
  test "creates project with valid attributes" do
    attributes = {
      title: "Calculator App",
      description: "Build a calculator application",
      exercise_slug: "calculator"
    }

    project = Project::Create.(attributes)

    assert_equal "Calculator App", project.title
    assert_equal "Build a calculator application", project.description
    assert_equal "calculator", project.exercise_slug
    assert project.persisted?
  end

  test "raises validation error for invalid attributes" do
    attributes = { title: "" }

    assert_raises ActiveRecord::RecordInvalid do
      Project::Create.(attributes)
    end
  end
end
