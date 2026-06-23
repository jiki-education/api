require "test_helper"

class Mailshot::RenderPreviewTest < ActiveSupport::TestCase
  test "renders the mailshot markdown into compiled email HTML" do
    user = create(:user)
    mailshot = create(:mailshot, subject: "Big news", body_markdown: "## Heading\n\n**bold**")

    html = Mailshot::RenderPreview.(mailshot, user)

    assert_match "bold", html
    assert_match(%r{<strong>bold</strong>}, html)
    assert_match(/<table/, html) # MJML compiled to HTML tables
    refute_match(/<mj-/, html)   # no raw MJML left
  end
end
