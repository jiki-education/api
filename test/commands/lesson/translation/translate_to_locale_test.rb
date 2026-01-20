require "test_helper"

class Lesson::Translation::TranslateToLocaleTest < ActiveSupport::TestCase
  test "creates translated lesson with correct attributes" do
    lesson = create(:lesson, :exercise,
      slug: "variables-intro",
      title: "Introduction to Variables",
      description: "Learn about variables in programming")

    translation = {
      title: "Bevezetés a változókba",
      description: "Ismerje meg a változókat a programozásban"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Lesson::Translation::TranslateToLocale.(lesson, "hu")

    assert target.persisted?
    assert_equal lesson.id, target.lesson_id
    assert_equal "hu", target.locale
    assert_equal "Bevezetés a változókba", target.title
    assert_equal "Ismerje meg a változókat a programozásban", target.description
  end

  test "calls Gemini::Translate with correct parameters" do
    lesson = create(:lesson, :exercise,
      slug: "variables-intro",
      title: "Variables",
      description: "Learn variables")

    translation = {
      title: "Test",
      description: "Test"
    }

    Gemini::Translate.expects(:call).with(
      instance_of(String),
      instance_of(Hash),
      model: :flash
    ).returns(translation)

    result = Lesson::Translation::TranslateToLocale.(lesson, "hu")

    assert result.persisted?
  end

  test "raises error if target locale is English" do
    lesson = create(:lesson, :exercise)

    error = assert_raises ArgumentError do
      Lesson::Translation::TranslateToLocale.(lesson, "en")
    end

    assert_equal "Target locale cannot be English (en)", error.message
  end

  test "raises error if target locale is not supported" do
    lesson = create(:lesson, :exercise)

    error = assert_raises ArgumentError do
      Lesson::Translation::TranslateToLocale.(lesson, "unsupported")
    end

    assert_equal "Target locale not supported", error.message
  end

  test "deletes existing translation before creating new one (upsert)" do
    lesson = create(:lesson, :exercise,
      slug: "variables-intro",
      title: "Variables",
      description: "Learn variables")
    existing = create(:lesson_translation,
      lesson:,
      locale: "hu",
      title: "Old Title",
      description: "Old Description")

    translation = {
      title: "New Title",
      description: "New Description"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Lesson::Translation::TranslateToLocale.(lesson, "hu")

    refute Lesson::Translation.exists?(existing.id)
    assert target.persisted?
    assert_equal "New Title", target.title
  end

  test "translation prompt includes lesson context" do
    lesson = create(:lesson, :exercise,
      slug: "variables-intro",
      title: "Variables",
      description: "Learn variables")

    translation = {
      title: "Test",
      description: "Test"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    Lesson::Translation::TranslateToLocale.(lesson, "hu")

    command = Lesson::Translation::TranslateToLocale.new(lesson, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Lesson: Variables (variables-intro)"
    assert_includes prompt, "Lesson Type: exercise"
    assert_includes prompt, "Target Language: Hungarian (hu)"
  end

  test "translation prompt includes both source fields" do
    lesson = create(:lesson, :exercise,
      title: "Unique Lesson Title",
      description: "Unique lesson description text")

    command = Lesson::Translation::TranslateToLocale.new(lesson, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Unique Lesson Title"
    assert_includes prompt, "Unique lesson description text"
  end

  test "translation prompt has localization expert instructions" do
    lesson = create(:lesson, :exercise)

    command = Lesson::Translation::TranslateToLocale.new(lesson, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "professional localization expert"
    assert_includes prompt, "Maintain the original meaning, tone, and educational intent"
    assert_includes prompt, "Preserve any markdown formatting"
    assert_includes prompt, "Return ONLY a valid JSON object"
  end

  test "raises Gemini::RateLimitError when rate limited" do
    lesson = create(:lesson, :exercise)

    Gemini::Translate.stubs(:call).raises(Gemini::RateLimitError, "Rate limit exceeded")

    error = assert_raises Gemini::RateLimitError do
      Lesson::Translation::TranslateToLocale.(lesson, "hu")
    end

    assert_includes error.message, "Rate limit exceeded"
  end
end
