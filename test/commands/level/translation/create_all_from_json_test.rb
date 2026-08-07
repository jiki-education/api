require "test_helper"

class Level::Translation::CreateAllFromJsonTest < ActiveSupport::TestCase
  test "creates translations from valid JSON, matched by level uuid + locale" do
    level = create(:level, uuid: "level-uuid-1")

    sync!([entry(level_uuid: "level-uuid-1", locale: "hu")])

    translation = Level::Translation.find_for(level, "hu")
    assert translation
    assert_equal "Subject hu", translation.milestone_email_subject
    assert_equal "Body hu", translation.milestone_email_content_markdown
  end

  test "is idempotent - running twice keeps the same record, updated in place" do
    level = create(:level, uuid: "level-uuid-1")

    sync!([entry(level_uuid: "level-uuid-1", locale: "hu")])
    translation_id = Level::Translation.find_for(level, "hu").id

    sync!([entry(level_uuid: "level-uuid-1", locale: "hu", subject: "Updated subject")])

    assert_equal 1, Level::Translation.count
    translation = Level::Translation.find_for(level, "hu")
    assert_equal translation_id, translation.id
    assert_equal "Updated subject", translation.milestone_email_subject
  end

  test "raises for a level uuid that doesn't exist" do
    error = assert_raises InvalidJsonError do
      sync!([entry(level_uuid: "missing-uuid", locale: "hu")])
    end

    assert_match(/Level not found/, error.message)
  end

  test "raises for invalid JSON" do
    file = Tempfile.new(["invalid", ".json"])
    file.write("{ invalid json")
    file.close

    error = assert_raises InvalidJsonError do
      Level::Translation::CreateAllFromJson.(file.path)
    end

    assert_match(/Invalid JSON/, error.message)
  ensure
    file.unlink
  end

  test "raises for a missing file" do
    error = assert_raises InvalidJsonError do
      Level::Translation::CreateAllFromJson.("/nonexistent/path.json")
    end

    assert_match(/File not found/, error.message)
  end

  test "raises when an entry is missing a required field" do
    error = assert_raises InvalidJsonError do
      sync!([entry(level_uuid: "level-uuid-1", locale: "hu").except("milestone_email_subject")])
    end

    assert_match(/missing required 'milestone_email_subject' field/, error.message)
  end

  private
  def sync!(entries)
    file = Tempfile.new(["level_translations", ".json"])
    file.write(JSON.generate(entries))
    file.close

    Level::Translation::CreateAllFromJson.(file.path)
  ensure
    file.unlink
  end

  def entry(level_uuid:, locale:, subject: "Subject #{locale}", body: "Body #{locale}")
    {
      "level_uuid" => level_uuid,
      "locale" => locale,
      "milestone_email_subject" => subject,
      "milestone_email_content_markdown" => body
    }
  end
end
