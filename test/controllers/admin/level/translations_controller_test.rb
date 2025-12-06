require "test_helper"

class Admin::Level::TranslationsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    @headers = auth_headers_for(@admin)
    @level = create(:level, slug: "ruby-basics")
  end

  # Authentication and authorization guards
  guard_admin! :translate_admin_level_translations_path, args: ["ruby-basics"], method: :post

  # POST translate tests

  test "POST translate queues translation jobs" do
    target_locales = %w[hu fr es de]
    Level::Translation::TranslateToAllLocales.expects(:call).with(@level).returns(target_locales)

    post translate_admin_level_translations_path(level_id: @level.slug),
      headers: @headers,
      as: :json

    assert_response :accepted
  end

  test "POST translate returns level_slug and queued_locales" do
    target_locales = %w[hu fr es de]
    Level::Translation::TranslateToAllLocales.stubs(:call).returns(target_locales)

    post translate_admin_level_translations_path(level_id: @level.slug),
      headers: @headers,
      as: :json

    assert_response :accepted

    json = response.parsed_body
    assert_equal "ruby-basics", json["level_slug"]
    assert_equal %w[hu fr es de], json["queued_locales"]
  end

  test "POST translate calls Level::Translation::TranslateToAllLocales command" do
    Level::Translation::TranslateToAllLocales.expects(:call).with(@level).returns([])

    post translate_admin_level_translations_path(level_id: @level.slug),
      headers: @headers,
      as: :json

    assert_response :accepted
  end

  test "POST translate returns 404 for non-existent level" do
    post translate_admin_level_translations_path(level_id: "non-existent"),
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
end
