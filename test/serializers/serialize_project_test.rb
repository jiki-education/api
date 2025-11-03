require "test_helper"

class SerializeProjectTest < ActiveSupport::TestCase
  test "serializes project with all required fields" do
    project = create(:project, slug: "calculator", title: "Calculator", description: "Build a calculator")

    expected = {
      slug: "calculator",
      title: "Calculator",
      description: "Build a calculator"
    }

    assert_equal expected, SerializeProject.(project)
  end
end
