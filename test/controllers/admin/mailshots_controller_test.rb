require "test_helper"

class Admin::MailshotsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_mailshots_path, method: :get
  guard_admin! :admin_mailshots_path, method: :post
  guard_admin! :admin_mailshot_path, args: [1], method: :get
  guard_admin! :admin_mailshot_path, args: [1], method: :patch
  guard_admin! :admin_mailshot_path, args: [1], method: :delete
  guard_admin! :preview_admin_mailshot_path, args: [1], method: :post
  guard_admin! :send_test_admin_mailshot_path, args: [1], method: :post
  guard_admin! :send_admin_mailshot_path, args: [1], method: :post

  # INDEX

  test "GET index returns mailshots newest first with pagination" do
    Prosopite.finish
    older = create(:mailshot, created_at: 2.days.ago)
    newer = create(:mailshot, created_at: 1.day.ago)

    Prosopite.scan
    get admin_mailshots_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeMailshots.([newer, older]),
      meta: { current_page: 1, total_pages: 1, total_count: 2 }
    })
  end

  # SHOW

  test "GET show returns the mailshot" do
    mailshot = create(:mailshot)

    get admin_mailshot_path(mailshot), as: :json

    assert_response :success
    assert_json_response({ mailshot: SerializeMailshot.(mailshot) })
  end

  test "GET show returns 404 for an unknown mailshot" do
    get admin_mailshot_path(0), as: :json

    assert_json_error(:not_found, error_type: :mailshot_not_found)
  end

  # CREATE

  test "POST create makes a mailshot" do
    assert_difference "Mailshot.count", 1 do
      post admin_mailshots_path,
        params: { mailshot: { slug: "launch", subject: "We launched", body_markdown: "Hi" } },
        as: :json
    end

    assert_response :created
    assert_json_response({ mailshot: SerializeMailshot.(Mailshot.last) })
  end

  test "POST create makes a draft without a body" do
    assert_difference "Mailshot.count", 1 do
      post admin_mailshots_path,
        params: { mailshot: { slug: "draft", subject: "Draft" } },
        as: :json
    end

    assert_response :created
    assert_equal "", Mailshot.last.body_markdown
  end

  test "POST create rejects a preference key outside the allowed list" do
    post admin_mailshots_path,
      params: { mailshot: { slug: "x", subject: "x", email_communication_preferences_key: "event_emails" } },
      as: :json

    assert_json_error(
      :unprocessable_entity,
      error_type: :validation_error,
      errors: { email_communication_preferences_key: ["is not included in the list"] }
    )
  end

  test "POST create returns validation errors" do
    post admin_mailshots_path,
      params: { mailshot: { body_markdown: "Hi" } },
      as: :json

    assert_json_error(
      :unprocessable_entity,
      error_type: :validation_error,
      errors: { slug: ["can't be blank"], subject: ["can't be blank"] }
    )
  end

  # UPDATE

  test "PATCH update changes the mailshot" do
    mailshot = create(:mailshot)

    patch admin_mailshot_path(mailshot),
      params: { mailshot: { subject: "Edited subject" } },
      as: :json

    assert_response :success
    assert_equal "Edited subject", mailshot.reload.subject
    assert_json_response({ mailshot: SerializeMailshot.(mailshot) })
  end

  # DESTROY

  test "DELETE destroy removes a draft" do
    mailshot = create(:mailshot)

    assert_difference "Mailshot.count", -1 do
      delete admin_mailshot_path(mailshot), as: :json
    end

    assert_response :no_content
  end

  test "DELETE destroy refuses an already-sent mailshot" do
    mailshot = create(:mailshot, :sent)

    assert_no_difference "Mailshot.count" do
      delete admin_mailshot_path(mailshot), as: :json
    end

    assert_json_error(:unprocessable_entity, error_type: :mailshot_already_sent)
  end

  # PREVIEW

  test "POST preview renders HTML from the submitted content without saving" do
    mailshot = create(:mailshot, body_markdown: "saved body")

    post preview_admin_mailshot_path(mailshot),
      params: { mailshot: { subject: "Live subject", body_markdown: "live body" } },
      as: :json

    assert_response :success
    assert_match "live body", response.parsed_body["html"]
    assert_equal "saved body", mailshot.reload.body_markdown
  end

  # TEST SEND

  test "POST test sends to the current admin" do
    mailshot = create(:mailshot)

    assert_enqueued_jobs 1, only: MailDeliveryJob do
      post send_test_admin_mailshot_path(mailshot), as: :json
    end

    assert_response :success
    assert_json_response({ success: true })
  end

  # SEND

  test "POST send records the audience and returns the count" do
    create_list(:user, 2)
    mailshot = create(:mailshot)

    post send_admin_mailshot_path(mailshot), params: { segment: "all_users" }, as: :json

    assert_response :success
    assert_equal ["all_users"], mailshot.reload.sent_to_audiences
    assert_equal User.count, response.parsed_body["audience_count"]
    assert_json_response({ mailshot: SerializeMailshot.(mailshot), audience_count: User.count })
  end

  test "POST send is a no-op and returns 0 for an already-sent segment" do
    mailshot = create(:mailshot, :sent)

    Mailshot::SendToSegment.expects(:defer).never
    post send_admin_mailshot_path(mailshot), params: { segment: "all_users" }, as: :json

    assert_response :success
    assert_equal 0, response.parsed_body["audience_count"]
  end

  test "POST send rejects a mailshot with no body" do
    mailshot = create(:mailshot, body_markdown: "")

    Mailshot::SendToSegment.expects(:defer).never
    post send_admin_mailshot_path(mailshot), params: { segment: "all_users" }, as: :json

    assert_json_error(:unprocessable_entity, error_type: :mailshot_body_blank)
  end

  test "POST send rejects an unknown segment" do
    mailshot = create(:mailshot)

    post send_admin_mailshot_path(mailshot), params: { segment: "nonsense" }, as: :json

    assert_json_error(:unprocessable_entity, error_type: :unknown_segment, segment: "nonsense")
  end
end
