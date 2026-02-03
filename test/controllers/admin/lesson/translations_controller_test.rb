require "test_helper"

class Admin::Lesson::TranslationsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
    @lesson = create(:lesson, :exercise, slug: "variables-intro")
  end

  # Authentication and authorization guards
  guard_admin! :translate_admin_lesson_translations_path, args: ["variables-intro"], method: :post

  # POST translate tests

  test "POST translate queues translation jobs" do
    target_locales = %w[hu fr es de]
    Lesson::Translation::TranslateToAllLocales.expects(:call).with(@lesson).returns(target_locales)

    post translate_admin_lesson_translations_path(lesson_id: @lesson.slug),
      as: :json

    assert_response :accepted
  end

  test "POST translate returns lesson_slug and queued_locales" do
    target_locales = %w[hu fr es de]
    Lesson::Translation::TranslateToAllLocales.stubs(:call).returns(target_locales)

    post translate_admin_lesson_translations_path(lesson_id: @lesson.slug),
      as: :json

    assert_response :accepted

    json = response.parsed_body
    assert_equal "variables-intro", json["lesson_slug"]
    assert_equal %w[hu fr es de], json["queued_locales"]
  end

  test "POST translate calls Lesson::Translation::TranslateToAllLocales command" do
    Lesson::Translation::TranslateToAllLocales.expects(:call).with(@lesson).returns([])

    post translate_admin_lesson_translations_path(lesson_id: @lesson.slug),
      as: :json

    assert_response :accepted
  end

  test "POST translate returns 404 for non-existent lesson" do
    post translate_admin_lesson_translations_path(lesson_id: "non-existent"),
      as: :json

    assert_json_error(:not_found, error_type: :lesson_not_found)
  end
end
