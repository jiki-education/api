require "test_helper"

class SerializeLessonTest < ActiveSupport::TestCase
  test "serializes lesson with core fields by default (without data)" do
    lesson = create(:lesson, :exercise, slug: "hello-world")

    expected = {
      slug: "hello-world",
      type: "exercise",
      walkthrough_video_data: nil
    }

    assert_equal(expected, SerializeLesson.(lesson, nil))
  end

  test "serializes lesson with data when include_data is true" do
    user = create(:user)
    lesson = create(:lesson, :video, slug: "test", data: { sources: [{ id: "abc123" }] })

    expected = {
      slug: "test",
      type: "video",
      walkthrough_video_data: nil,
      data: { sources: [{ id: "abc123" }] }
    }

    assert_equal(expected, SerializeLesson.(lesson, user, include_data: true))
  end

  # Titles and descriptions are authored in the front-end curriculum repo
  # (curriculum/src/exercises/<slug>/instructions/*.md), per locale.
  test "does not include title or description" do
    lesson = create(:lesson, :exercise, slug: "intro")

    result = SerializeLesson.(lesson, nil)

    refute result.key?(:title)
    refute result.key?(:description)
  end

  test "excludes data by default" do
    lesson = create(:lesson, :exercise, slug: "intro")

    result = SerializeLesson.(lesson, nil)
    refute result.key?(:data)
  end

  test "exercise lessons carry empty data" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "intro")

    result = SerializeLesson.(lesson, user, include_data: true)
    assert_empty result[:data]
  end

  test "filters sources by user's language choice" do
    user = create(:user)
    course = create(:course)
    level = create(:level, course: course)
    lesson = create(:lesson, :video, level: level, slug: "intro",
      data: { sources: [
        { id: "js-video", language: "javascript" },
        { id: "py-video", language: "python" },
        { id: "common-video" }
      ] })
    create(:user_course, user: user, course: course, language: "javascript")

    result = SerializeLesson.(lesson, user, include_data: true)

    assert_equal 2, result[:data][:sources].length
    assert_includes result[:data][:sources], { id: "js-video", language: "javascript" }
    assert_includes result[:data][:sources], { id: "common-video" }
    refute_includes result[:data][:sources], { id: "py-video", language: "python" }
  end

  test "returns all sources when user has no language set" do
    user = create(:user)
    course = create(:course)
    level = create(:level, course: course)
    lesson = create(:lesson, :video, level: level, slug: "intro",
      data: { sources: [
        { id: "js-video", language: "javascript" },
        { id: "py-video", language: "python" }
      ] })
    create(:user_course, user: user, course: course, language: nil)

    result = SerializeLesson.(lesson, user, include_data: true)

    assert_equal 2, result[:data][:sources].length
  end

  test "raises error when include_data is true but user is nil" do
    lesson = create(:lesson, :video, slug: "intro", data: { sources: [{ id: "video" }] })

    error = assert_raises(RuntimeError) do
      SerializeLesson.(lesson, nil, include_data: true)
    end

    assert_equal "user is required when include_data is true", error.message
  end
end
