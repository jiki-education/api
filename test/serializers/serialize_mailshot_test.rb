require "test_helper"

class SerializeMailshotTest < ActiveSupport::TestCase
  test "serializes a mailshot" do
    mailshot = create(:mailshot,
      slug: "june-news",
      subject: "June news",
      body_markdown: "## Hello",
      sent_to_audiences: ["premium_users"])
    create(:user_mailshot, mailshot:)

    assert_equal(
      {
        id: mailshot.id,
        slug: "june-news",
        subject: "June news",
        body_markdown: "## Hello",
        email_communication_preferences_key: "newsletters",
        sent_to_audiences: ["premium_users"],
        sent_count: 1,
        created_at: mailshot.created_at.iso8601,
        updated_at: mailshot.updated_at.iso8601
      },
      SerializeMailshot.(mailshot)
    )
  end
end
