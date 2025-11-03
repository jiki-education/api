require "test_helper"

class Project::UpdateTest < ActiveSupport::TestCase
  test "updates project with valid attributes" do
    project = create :project, title: "Original"

    Project::Update.(project, { title: "Updated" })

    assert_equal "Updated", project.title
  end

  test "raises validation error for invalid attributes" do
    project = create :project

    assert_raises ActiveRecord::RecordInvalid do
      Project::Update.(project, { title: "" })
    end
  end

  test "returns the updated project" do
    project = create :project

    result = Project::Update.(project, { title: "New Title" })

    assert_equal project, result
    assert_equal "New Title", result.title
  end
end
