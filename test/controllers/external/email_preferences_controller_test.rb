require "test_helper"

class External::EmailPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "GET show returns preferences with valid token" do
    user = create(:user)

    get external_email_preference_path(token: user.data.unsubscribe_token), as: :json

    assert_response :success
    assert_json_response({
      email_preferences: SerializeEmailPreferences.(user)
    })
  end

  test "GET show returns 404 for invalid token" do
    get external_email_preference_path(token: "invalid-token"), as: :json

    assert_json_error(:not_found, error_type: :invalid_unsubscribe_token)
  end

  test "PATCH update changes specific preferences" do
    user = create(:user)
    assert user.data.receive_newsletters?

    patch external_email_preference_path(token: user.data.unsubscribe_token),
      params: { newsletters: false },
      as: :json

    assert_response :success
    refute user.data.reload.receive_newsletters?
    assert_json_response({
      email_preferences: SerializeEmailPreferences.(user.reload)
    })
  end

  test "PATCH update can update multiple preferences" do
    user = create(:user)
    assert user.data.receive_newsletters?
    assert user.data.receive_event_emails?

    patch external_email_preference_path(token: user.data.unsubscribe_token),
      params: { newsletters: false, event_emails: false },
      as: :json

    assert_response :success
    refute user.data.reload.receive_newsletters?
    refute user.data.receive_event_emails?
  end

  test "PATCH update returns 404 for invalid token" do
    patch external_email_preference_path(token: "invalid-token"),
      params: { newsletters: false },
      as: :json

    assert_response :not_found
  end

  test "PATCH update ignores invalid preference slugs" do
    user = create(:user)
    original_newsletters = user.data.receive_newsletters?

    patch external_email_preference_path(token: user.data.unsubscribe_token),
      params: { invalid_preference: false },
      as: :json

    assert_response :success
    # Invalid slugs are filtered out by strong params, so nothing changes
    assert_equal original_newsletters, user.data.reload.receive_newsletters?
  end

  test "POST unsubscribe_all sets all preferences to false" do
    user = create(:user)
    assert user.data.receive_newsletters?
    assert user.data.receive_event_emails?
    assert user.data.receive_milestone_emails?
    assert user.data.receive_activity_emails?

    post unsubscribe_all_external_email_preference_path(token: user.data.unsubscribe_token),
      as: :json

    assert_response :success
    user.data.reload
    refute user.data.receive_newsletters?
    refute user.data.receive_event_emails?
    refute user.data.receive_milestone_emails?
    refute user.data.receive_activity_emails?
  end

  test "POST unsubscribe_all returns 404 for invalid token" do
    post unsubscribe_all_external_email_preference_path(token: "invalid-token"),
      as: :json

    assert_response :not_found
  end

  test "POST subscribe_all sets all preferences to true" do
    user = create(:user)
    user.data.update!(
      receive_newsletters: false,
      receive_event_emails: false,
      receive_milestone_emails: false,
      receive_activity_emails: false
    )

    post subscribe_all_external_email_preference_path(token: user.data.unsubscribe_token),
      as: :json

    assert_response :success
    user.data.reload
    assert user.data.receive_newsletters?
    assert user.data.receive_event_emails?
    assert user.data.receive_milestone_emails?
    assert user.data.receive_activity_emails?
  end

  test "POST subscribe_all returns 404 for invalid token" do
    post subscribe_all_external_email_preference_path(token: "invalid-token"),
      as: :json

    assert_response :not_found
  end
end
