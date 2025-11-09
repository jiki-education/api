require "test_helper"

class Internal::LevelsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_levels_path, method: :get

  test "GET index returns all levels with nested lessons" do
    level1 = create(:level, slug: "level-1")
    level2 = create(:level, slug: "level-2")
    create(:lesson, level: level1, slug: "lesson-1", type: "exercise", data: { slug: :ex1 })
    create(:lesson, level: level1, slug: "lesson-2", type: "tutorial", data: { slug: :ex2 })
    create(:lesson, level: level2, slug: "lesson-3", type: "exercise", data: { slug: :ex3 })

    get internal_levels_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      levels: SerializeLevels.([level1, level2])
    })
  end

  test "GET index returns empty array when no levels exist" do
    get internal_levels_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({ levels: [] })
  end

  test "GET index returns correct JSON structure" do
    level = create(:level)
    create(:lesson, level: level)

    get internal_levels_path, headers: @headers, as: :json

    assert_response :success

    assert_json_structure({
      levels: [
        {
          slug: String,
          lessons: [
            {
              slug: String,
              type: String
            }
          ]
        }
      ]
    })
  end

  test "GET index uses SerializeLevels" do
    Prosopite.finish # Stop scan before creating test data
    levels = create_list(:level, 2)
    serialized_data = [{ slug: "test" }]

    SerializeLevels.expects(:call).with { |arg| arg.to_a == levels }.returns(serialized_data)

    Prosopite.scan # Resume scan for the actual request
    get internal_levels_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({ levels: serialized_data })
  end
end
