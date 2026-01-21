require "test_helper"

class Internal::PaymentsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_payments_path, method: :get

  # Index action tests
  test "GET index returns empty array when no payments" do
    get internal_payments_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({ payments: [] })
  end

  test "GET index returns user's payments" do
    payment1 = create(:payment, user: @current_user, created_at: 2.days.ago)
    payment2 = create(:payment, user: @current_user, created_at: 1.day.ago)

    get internal_payments_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      payments: SerializePayments.([payment2, payment1])
    })
  end

  test "GET index does not return other user's payments" do
    other_user = create(:user)
    create(:payment, user: other_user)
    my_payment = create(:payment, user: @current_user)

    get internal_payments_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["payments"].length
    assert_equal my_payment.id, json["payments"].first["id"]
  end

  test "GET index returns payments in most recent first order" do
    old_payment = create(:payment, user: @current_user, created_at: 1.week.ago)
    new_payment = create(:payment, user: @current_user, created_at: 1.day.ago)

    get internal_payments_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal new_payment.id, json["payments"].first["id"]
    assert_equal old_payment.id, json["payments"].last["id"]
  end

  test "GET index uses SerializePayments" do
    create(:payment, user: @current_user)

    SerializePayments.expects(:call).returns([])

    get internal_payments_path, headers: @headers, as: :json

    assert_response :success
  end
end
