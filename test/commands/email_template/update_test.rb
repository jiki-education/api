require "test_helper"

class EmailTemplate::UpdateTest < ActiveSupport::TestCase
  test "updates email template with all valid params" do
    email_template = create(:email_template)

    result = EmailTemplate::Update.(
      email_template,
      {
        subject: "New Subject",
        body_mjml: "<mj-section><mj-column><mj-text>New MJML</mj-text></mj-column></mj-section>",
        body_text: "New text body"
      }
    )

    assert_equal email_template, result
    assert_equal "New Subject", email_template.reload.subject
    assert_equal "<mj-section><mj-column><mj-text>New MJML</mj-text></mj-column></mj-section>", email_template.body_mjml
    assert_equal "New text body", email_template.body_text
  end

  test "updates subject only" do
    email_template = create(:email_template, subject: "Old Subject")
    original_mjml = email_template.body_mjml
    original_text = email_template.body_text

    EmailTemplate::Update.(email_template, { subject: "New Subject" })

    assert_equal "New Subject", email_template.reload.subject
    assert_equal original_mjml, email_template.body_mjml
    assert_equal original_text, email_template.body_text
  end

  test "updates body_mjml only" do
    email_template = create(:email_template)
    original_subject = email_template.subject
    original_text = email_template.body_text

    new_mjml = "<mj-section><mj-column><mj-text>Updated</mj-text></mj-column></mj-section>"
    EmailTemplate::Update.(email_template, { body_mjml: new_mjml })

    assert_equal original_subject, email_template.reload.subject
    assert_equal new_mjml, email_template.body_mjml
    assert_equal original_text, email_template.body_text
  end

  test "updates body_text only" do
    email_template = create(:email_template)
    original_subject = email_template.subject
    original_mjml = email_template.body_mjml

    EmailTemplate::Update.(email_template, { body_text: "New text" })

    assert_equal original_subject, email_template.reload.subject
    assert_equal original_mjml, email_template.body_mjml
    assert_equal "New text", email_template.body_text
  end

  test "raises validation error with blank subject" do
    email_template = create(:email_template)

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Update.(email_template, { subject: "" })
    end

    assert_match(/Subject/, error.message)
  end

  test "raises validation error with blank body_mjml" do
    email_template = create(:email_template)

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Update.(email_template, { body_mjml: "" })
    end

    assert_match(/Body mjml/, error.message)
  end

  test "raises validation error with blank body_text" do
    email_template = create(:email_template)

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Update.(email_template, { body_text: "" })
    end

    assert_match(/Body text/, error.message)
  end

  test "updates type parameter" do
    email_template = create(:email_template, type: :level_completion)

    EmailTemplate::Update.(
      email_template,
      {
        type: :level_completion,
        subject: "New Subject"
      }
    )

    assert_equal "level_completion", email_template.reload.type
    assert_equal "New Subject", email_template.subject
  end

  test "updates slug parameter" do
    email_template = create(:email_template, slug: "original-slug")

    EmailTemplate::Update.(
      email_template,
      {
        slug: "new-slug",
        subject: "New Subject"
      }
    )

    assert_equal "new-slug", email_template.reload.slug
    assert_equal "New Subject", email_template.subject
  end

  test "updates locale parameter" do
    email_template = create(:email_template, locale: "en")

    EmailTemplate::Update.(
      email_template,
      {
        locale: "hu",
        subject: "New Subject"
      }
    )

    assert_equal "hu", email_template.reload.locale
    assert_equal "New Subject", email_template.subject
  end

  test "raises error for duplicate type, slug, and locale combination on update" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    email_template = create(:email_template, type: :level_completion, slug: "level-2", locale: "en")

    assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Update.(
        email_template,
        {
          slug: "level-1"
        }
      )
    end
  end

  test "allows updating to same type, slug with different locale" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    email_template = create(:email_template, type: :level_completion, slug: "level-1", locale: "hu")

    EmailTemplate::Update.(
      email_template,
      {
        subject: "Updated Subject"
      }
    )

    assert_equal "Updated Subject", email_template.reload.subject
    assert_equal "hu", email_template.locale
  end
end
