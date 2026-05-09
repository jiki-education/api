require "test_helper"

class External::PricingControllerTest < ActionDispatch::IntegrationTest
  test "returns localised prices based on CF-IPCountry header" do
    get external_pricing_path, headers: { "CF-IPCountry" => "BR" }, as: :json

    assert_response :success
    assert_json_response({
      premium_prices: {
        currency: :brl,
        monthly: PREMIUM_PRICES[:brl][:monthly],
        annual: PREMIUM_PRICES[:brl][:annual],
        country_code: "BR"
      }
    })
  end

  test "falls back to usd when header is missing" do
    get external_pricing_path, as: :json

    assert_response :success
    assert_json_response({
      premium_prices: {
        currency: :usd,
        monthly: PREMIUM_PRICES[:usd][:monthly],
        annual: PREMIUM_PRICES[:usd][:annual],
        country_code: nil
      }
    })
  end

  test "falls back to usd when country has no currency mapping" do
    get external_pricing_path, headers: { "CF-IPCountry" => "XX" }, as: :json

    assert_response :success
    assert_json_response({
      premium_prices: {
        currency: :usd,
        monthly: PREMIUM_PRICES[:usd][:monthly],
        annual: PREMIUM_PRICES[:usd][:annual],
        country_code: "XX"
      }
    })
  end
end
