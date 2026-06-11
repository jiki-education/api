require "test_helper"

class Exercism::FetchEntitledUsersTest < ActiveSupport::TestCase
  setup { stub_exercism_secrets! }
  teardown { unstub_exercism_secrets! }

  test "GETs the roster and parses id arrays" do
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/v2/jiki/entitled_users").
      with(headers: { "Authorization" => "Bearer test-exercism-api-key" }).
      to_return(
        status: 200,
        body: { insider_ids: [1, 2, 3], bootcamp_member_ids: [4, 5] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Exercism::FetchEntitledUsers.()

    assert_equal({
      "insider_ids" => %w[1 2 3],
      "bootcamp_member_ids" => %w[4 5]
    }, result)
  end

  test "returns empty arrays when the response omits keys" do
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/v2/jiki/entitled_users").
      to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

    assert_equal({ "insider_ids" => [], "bootcamp_member_ids" => [] }, Exercism::FetchEntitledUsers.())
  end

  test "raises on non-success" do
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/v2/jiki/entitled_users").
      to_return(status: 500, body: "boom")

    assert_raises(FetchExercismUserStatusesError) { Exercism::FetchEntitledUsers.() }
  end
end
