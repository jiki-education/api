require "test_helper"

class User::TrackSignupTest < ActiveSupport::TestCase
  test "defers user_signed_up event with provider" do
    user = create(:user)

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: { provider: "email" }
    )

    User::TrackSignup.(user, "email")
  end

  test "merges attribution into event properties" do
    user = create(:user)
    attribution = { "utm_source" => "twitter", "referrer" => "https://t.co/foo" }

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: { provider: "google", "utm_source" => "twitter", "referrer" => "https://t.co/foo" }
    )

    User::TrackSignup.(user, "google", attribution: attribution)
  end

  test "persists attribution to user.data" do
    user = create(:user)
    attribution = { "utm_source" => "twitter" }

    Analytics::TrackEvent.stubs(:defer)
    User::Identify.stubs(:defer)

    User::TrackSignup.(user, "email", attribution: attribution)

    assert_equal attribution, user.data.reload.signup_attribution
  end

  test "does not touch user.data when attribution is nil" do
    user = create(:user)
    Analytics::TrackEvent.stubs(:defer)
    User::Identify.stubs(:defer)

    User::TrackSignup.(user, "email")

    assert_nil user.data.reload.signup_attribution
  end

  test "does not touch user.data when attribution is empty" do
    user = create(:user)
    Analytics::TrackEvent.stubs(:defer)
    User::Identify.stubs(:defer)

    User::TrackSignup.(user, "email", attribution: {})

    assert_nil user.data.reload.signup_attribution
  end
end
