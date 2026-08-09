require "test_helper"

class Level::Translation::CreateAllFromJsonTest < ActiveSupport::TestCase
  test "creates translations from valid JSON, locale derived from filename" do
    level = create(:level, uuid: "level-uuid-1")

    sync!("hu", [entry(level_uuid: "level-uuid-1")])

    translation = Level::Translation.find_for(level, "hu")
    assert translation
    assert_equal "Subject", translation.milestone_email_subject
    assert_equal "Body", translation.milestone_email_content_markdown
  end

  test "is idempotent - running twice keeps the same record, updated in place" do
    level = create(:level, uuid: "level-uuid-1")

    sync!("hu", [entry(level_uuid: "level-uuid-1")])
    translation_id = Level::Translation.find_for(level, "hu").id

    sync!("hu", [entry(level_uuid: "level-uuid-1", subject: "Updated subject")])

    assert_equal 1, Level::Translation.count
    translation = Level::Translation.find_for(level, "hu")
    assert_equal translation_id, translation.id
    assert_equal "Updated subject", translation.milestone_email_subject
  end

  test "raises for a level uuid that doesn't exist" do
    error = assert_raises InvalidJsonError do
      sync!("hu", [entry(level_uuid: "missing-uuid")])
    end

    assert_match(/Level not found/, error.message)
  end

  test "raises for invalid JSON" do
    dir = Dir.mktmpdir
    file_path = File.join(dir, "hu.json")
    File.write(file_path, "{ invalid json")

    error = assert_raises InvalidJsonError do
      Level::Translation::CreateAllFromJson.(file_path)
    end

    assert_match(/Invalid JSON/, error.message)
  ensure
    FileUtils.remove_entry(dir)
  end

  test "raises for a missing file" do
    error = assert_raises InvalidJsonError do
      Level::Translation::CreateAllFromJson.("/nonexistent/hu.json")
    end

    assert_match(/File not found/, error.message)
  end

  test "raises when an entry is missing a required field" do
    error = assert_raises InvalidJsonError do
      sync!("hu", [entry(level_uuid: "level-uuid-1").except("milestone_email_subject")])
    end

    assert_match(/missing required 'milestone_email_subject' field/, error.message)
  end

  private
  def sync!(locale, entries)
    dir = Dir.mktmpdir
    file_path = File.join(dir, "#{locale}.json")
    File.write(file_path, JSON.generate(entries))

    Level::Translation::CreateAllFromJson.(file_path)
  ensure
    FileUtils.remove_entry(dir)
  end

  def entry(level_uuid:, subject: "Subject", body: "Body")
    {
      "level_uuid" => level_uuid,
      "milestone_email_subject" => subject,
      "milestone_email_content_markdown" => body
    }
  end
end
