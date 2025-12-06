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

  # GET milestone tests

  guard_incorrect_token! :milestone_internal_level_path, args: ["ruby-basics"], method: :get

  test "GET milestone returns milestone for English (default locale)" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    get milestone_internal_level_path(level.slug),
      headers: @headers,
      as: :json

    assert_response :success

    I18n.with_locale(:en) do
      assert_json_response({
        milestone: SerializeLevelMilestone.(level)
      })
    end
  end

  test "GET milestone returns milestone for specific locale via param" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    create(:level_translation,
      level:,
      locale: "hu",
      title: "Ruby Alapok",
      description: "Tanuld meg",
      milestone_summary: "Szuper!",
      milestone_content: "# Kész!")

    get milestone_internal_level_path(level.slug, locale: "hu"),
      headers: @headers,
      as: :json

    assert_response :success

    I18n.with_locale(:hu) do
      assert_json_response({
        milestone: SerializeLevelMilestone.(level)
      })
    end
  end

  test "GET milestone falls back to English when translation missing" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    get milestone_internal_level_path(level.slug, locale: "fr"),
      headers: @headers,
      as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "Ruby Basics", json["milestone"]["title"] # Fallback to English
  end

  test "GET milestone returns milestone for user's locale when no param provided" do
    @current_user.update!(locale: "hu")
    level = create(:level)
    create(:level_translation, level:, locale: "hu", title: "Magyar cím")

    SerializeLevelMilestone.expects(:call).with(level).returns({ level_slug: "test" })

    get milestone_internal_level_path(level.slug),
      headers: @headers,
      as: :json

    assert_response :success
    assert_equal "hu", I18n.locale.to_s
  end

  test "GET milestone returns 404 for non-existent level" do
    get milestone_internal_level_path("non-existent"),
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Level not found"
      }
    })
  end

  test "GET milestone uses SerializeLevelMilestone" do
    level = create(:level, slug: "ruby-basics")
    serialized_data = { level_slug: "ruby-basics" }

    SerializeLevelMilestone.expects(:call).with(level).returns(serialized_data)

    get milestone_internal_level_path(level.slug),
      headers: @headers,
      as: :json

    assert_response :success
    assert_json_response({ milestone: serialized_data })
  end
end
