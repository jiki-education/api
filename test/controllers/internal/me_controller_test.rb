require "test_helper"

class Internal::MeControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  guard_incorrect_token! :internal_me_path, method: :get

  test "GET show returns current user data" do
    get internal_me_path, as: :json

    assert_response :success
    assert_json_response({ user: SerializeUser.(@current_user) })
  end

  test "GET show returns premium=true for a premium user" do
    make_premium(@current_user)

    get internal_me_path, as: :json

    assert_response :success
    assert_json_response({ user: SerializeUser.(@current_user) })
  end

  test "sets country_code from CF-IPCountry header when nil" do
    assert_nil @current_user.data.country_code

    get internal_me_path, headers: { "CF-IPCountry" => "IN" }, as: :json

    assert_response :success
    assert_equal "IN", @current_user.data.reload.country_code
  end

  test "does not overwrite existing country_code" do
    @current_user.data.update_column(:country_code, "GB")

    get internal_me_path, headers: { "CF-IPCountry" => "IN" }, as: :json

    assert_response :success
    assert_equal "GB", @current_user.data.reload.country_code
  end

  test "ignores XX country code from CF-IPCountry" do
    get internal_me_path, headers: { "CF-IPCountry" => "XX" }, as: :json

    assert_response :success
    assert_nil @current_user.data.reload.country_code
  end

  test "sets locales from Accept-Language header when empty" do
    assert_empty @current_user.data.locales

    get internal_me_path, headers: { "Accept-Language" => "hu, en-GB;q=0.9, en;q=0.8" }, as: :json

    assert_response :success
    assert_equal %w[hu en-GB en], @current_user.data.reload.locales
  end

  test "does not overwrite existing locales" do
    @current_user.data.update_column(:locales, %w[hu])

    get internal_me_path, headers: { "Accept-Language" => "en" }, as: :json

    assert_response :success
    assert_equal %w[hu], @current_user.data.reload.locales
  end

  test "ignores unparseable Accept-Language header" do
    get internal_me_path, headers: { "Accept-Language" => "!!!" }, as: :json

    assert_response :success
    assert_empty @current_user.data.reload.locales
  end

  test "GET show returns locale derived from stored locales" do
    @current_user.data.update_column(:locales, %w[hu en])

    get internal_me_path, as: :json

    assert_response :success
    assert_equal "hu", response.parsed_body["user"]["locale"]
  end
end
