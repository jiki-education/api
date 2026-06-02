require "test_helper"

# Tests ApplicationController#set_current_user_ip end-to-end: the request's IP
# is stored in Current.user_ip, materialised into deferred analytics jobs, and
# sent to PostHog as the $ip property.
class CurrentUserIpTest < ApplicationControllerTest
  setup do
    setup_user
  end

  test "uses CF-Connecting-IP header when present" do
    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with do |args|
      args[:properties][:"$ip"] == "86.41.10.20"
    end

    perform_enqueued_jobs do
      post internal_events_path,
        params: { event: "premium_modal_shown", properties: { trigger: "upgrade_cta_nav" } },
        headers: { "CF-Connecting-IP" => "86.41.10.20" },
        as: :json
    end

    assert_response :no_content
  end

  test "falls back to remote_ip without CF-Connecting-IP header" do
    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with do |args|
      # Integration test requests come from 127.0.0.1
      args[:properties][:"$ip"] == "127.0.0.1"
    end

    perform_enqueued_jobs do
      post internal_events_path,
        params: { event: "premium_modal_shown", properties: { trigger: "upgrade_cta_nav" } },
        as: :json
    end

    assert_response :no_content
  end
end
