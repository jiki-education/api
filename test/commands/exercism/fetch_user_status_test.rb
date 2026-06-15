require "test_helper"

class Exercism::FetchUserStatusTest < ActiveSupport::TestCase
  setup { stub_exercism_secrets! }
  teardown { unstub_exercism_secrets! }

  test "GETs the per-user endpoint and parses flags" do
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/v2/jiki/user_status/1530").
      with(headers: { "Authorization" => "Bearer test-exercism-api-key" }).
      to_return(
        status: 200,
        body: { is_insider: true, is_bootcamp_member: false }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Exercism::FetchUserStatus.("1530")

    assert_equal({ "is_insider" => true, "is_bootcamp_member" => false }, result)
  end

  test "coerces missing/non-boolean values to false" do
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/v2/jiki/user_status/1530").
      to_return(
        status: 200,
        body: { is_insider: nil, is_bootcamp_member: "yes" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Exercism::FetchUserStatus.("1530")

    refute result["is_insider"]
    refute result["is_bootcamp_member"]
  end

  test "raises on non-success" do
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/v2/jiki/user_status/1530").
      to_return(status: 500, body: "boom")

    assert_raises(FetchExercismUserStatusesError) { Exercism::FetchUserStatus.("1530") }
  end
end
