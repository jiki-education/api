require "test_helper"

class ProgressionMailerTest < ActionMailer::TestCase
  test "level_completed email renders correctly" do
    user = create(:user)
    level = create(:level)

    mail = ProgressionMailer.level_completed(UserLevel.new(user:, level:))

    assert_equal level.milestone_email_subject, mail.subject
    assert_equal [user.email], mail.to
    assert mail.html_part.body.to_s.present?
  end

  test "level_completed sets @header_image based on level.position % 3" do
    user = create(:user)
    level = create(:level)

    {
      3 => "milestone-1.jpg",
      1 => "milestone-2.jpg",
      2 => "milestone-3.jpg"
    }.each do |position, expected_image|
      level.stubs(:position).returns(position)

      mail = ProgressionMailer.level_completed(UserLevel.new(user:, level:))

      assert_match "static/emails/#{expected_image}", mail.html_part.body.to_s,
        "expected #{expected_image} for position #{position}"
    end
  end
end
