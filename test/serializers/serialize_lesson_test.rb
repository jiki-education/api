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

    assert_equal(expected, SerializeLesson.(lesson))
  end

  test "serializes lesson with data when include_data is true" do
    lesson = create(:lesson, :video, slug: "test", title: "Test Lesson", description: "A test lesson",
      data: { sources: [{ id: "abc123" }], difficulty: "easy", points: 10 })

    expected = {
      slug: "test",
      title: "Test Lesson",
      description: "A test lesson",
      type: "video",
      data: { sources: [{ id: "abc123" }], difficulty: "easy", points: 10 }
    }

    assert_equal(expected, SerializeLesson.(lesson, include_data: true))
  end

  test "uses translated content for non-English locale" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Introduction", description: "Start here")
    create(:lesson_translation, lesson: lesson, locale: "hu", title: "Bevezetés", description: "Kezdj itt")

    I18n.with_locale(:hu) do
      result = SerializeLesson.(lesson)
      assert_equal "Bevezetés", result[:title]
      assert_equal "Kezdj itt", result[:description]
    end
  end

  test "falls back to English when translation missing" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Introduction", description: "Start here")

    I18n.with_locale(:fr) do
      result = SerializeLesson.(lesson)
      assert_equal "Introduction", result[:title]
      assert_equal "Start here", result[:description]
    end
  end

  test "uses provided content parameter when given" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Original Title", description: "Original description")
    custom_content = { title: "Custom Title", description: "Custom description" }

    result = SerializeLesson.(lesson, content: custom_content)
    assert_equal "Custom Title", result[:title]
    assert_equal "Custom description", result[:description]
  end

  test "content parameter takes precedence over locale lookup" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "English Title", description: "English description")
    create(:lesson_translation, lesson: lesson, locale: "hu", title: "Magyar cím", description: "Magyar leírás")
    custom_content = { title: "Injected Title", description: "Injected description" }

    I18n.with_locale(:hu) do
      result = SerializeLesson.(lesson, content: custom_content)
      assert_equal "Injected Title", result[:title]
      assert_equal "Injected description", result[:description]
    end
  end

  test "excludes data by default" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Title", description: "Desc",
      data: { slug: "test-ex" })

    result = SerializeLesson.(lesson)
    refute result.key?(:data)
  end

  test "includes data when include_data is true" do
    lesson = create(:lesson, :exercise, slug: "intro", title: "Title", description: "Desc",
      data: { slug: "test-ex" })

    result = SerializeLesson.(lesson, include_data: true)
    assert_equal({ slug: "test-ex" }, result[:data])
  end
end
