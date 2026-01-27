require "test_helper"

class SerializeLessonTest < ActiveSupport::TestCase
  test "serializes lesson with core fields by default (without data)" do
    lesson = create(:lesson, :exercise, slug: "hello-world", title: "Hello World", description: "Learn the basics")

    expected = {
      slug: "hello-world",
      title: "Hello World",
      description: "Learn the basics",
      type: "exercise"
    }

    assert_equal(expected, SerializeLesson.(lesson, nil))
  end

  test "serializes lesson with data when include_data is true" do
    user = create(:user)
    lesson = create(:lesson, :video, slug: "test", title: "Test Lesson", description: "A test lesson",
      data: { sources: [{ id: "abc123" }], difficulty: "easy", points: 10 })

    expected = {
      slug: "test",
      title: "Test Lesson",
      description: "A test lesson",
      type: "video",
      data: { sources: [{ id: "abc123" }], difficulty: "easy", points: 10 }
    }

    assert_equal(expected, SerializeLesson.(lesson, user, include_data: true))
  end

  test "uses translated content for non-English locale" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Introduction", description: "Start here")
    create(:lesson_translation, lesson: lesson, locale: "hu", title: "Bevezetés", description: "Kezdj itt")

    I18n.with_locale(:hu) do
      result = SerializeLesson.(lesson, nil)
      assert_equal "Bevezetés", result[:title]
      assert_equal "Kezdj itt", result[:description]
    end
  end

  test "falls back to English when translation missing" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Introduction", description: "Start here")

    I18n.with_locale(:fr) do
      result = SerializeLesson.(lesson, nil)
      assert_equal "Introduction", result[:title]
      assert_equal "Start here", result[:description]
    end
  end

  test "uses provided content parameter when given" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Original Title", description: "Original description")
    custom_content = { title: "Custom Title", description: "Custom description" }

    result = SerializeLesson.(lesson, nil, content: custom_content)
    assert_equal "Custom Title", result[:title]
    assert_equal "Custom description", result[:description]
  end

  test "content parameter takes precedence over locale lookup" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "English Title", description: "English description")
    create(:lesson_translation, lesson: lesson, locale: "hu", title: "Magyar cím", description: "Magyar leírás")
    custom_content = { title: "Injected Title", description: "Injected description" }

    I18n.with_locale(:hu) do
      result = SerializeLesson.(lesson, nil, content: custom_content)
      assert_equal "Injected Title", result[:title]
      assert_equal "Injected description", result[:description]
    end
  end

  test "excludes data by default" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Title", description: "Desc",
      data: { slug: "test-ex" })

    result = SerializeLesson.(lesson, nil)
    refute result.key?(:data)
  end

  test "includes data when include_data is true" do
    user = create(:user)
    lesson = create(:lesson, :exercise, slug: "intro", title: "Title", description: "Desc",
      data: { slug: "test-ex" })

    result = SerializeLesson.(lesson, user, include_data: true)
    assert_equal({ slug: "test-ex" }, result[:data])
  end

  test "filters sources by user's language choice" do
    user = create(:user)
    course = create(:course)
    level = create(:level, course: course)
    lesson = create(:lesson, :video, level: level, slug: "intro", title: "Title", description: "Desc",
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
    lesson = create(:lesson, :video, level: level, slug: "intro", title: "Title", description: "Desc",
      data: { sources: [
        { id: "js-video", language: "javascript" },
        { id: "py-video", language: "python" }
      ] })
    create(:user_course, user: user, course: course, language: nil)

    result = SerializeLesson.(lesson, user, include_data: true)

    assert_equal 2, result[:data][:sources].length
  end

  test "raises error when include_data is true but user is nil" do
    lesson = create(:lesson, :video, slug: "intro", title: "Title", description: "Desc",
      data: { sources: [{ id: "video" }] })

    error = assert_raises(RuntimeError) do
      SerializeLesson.(lesson, nil, include_data: true)
    end

    assert_equal "user is required when include_data is true", error.message
  end
end
