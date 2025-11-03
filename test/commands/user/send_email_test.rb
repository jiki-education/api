require "test_helper"

class User::SendEmailTest < ActiveSupport::TestCase
  test "sends email when all conditions are met" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    assert_email_sent(user_level)
  end

  test "updates email status to sent" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    refute user_level.email_sent?

    User::SendEmail.(user_level) {}

    assert user_level.email_sent?
  end

  test "does not send if user may not receive emails" do
    user = create(:user, locale: "en")
    user.expects(may_receive_emails?: false)
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    refute_email_sent(user_level)
    assert user_level.email_skipped?
  end

  test "does not send if email template does not exist" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-2")
    # No template created for level-2
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    refute_email_sent(user_level)
    assert user_level.email_skipped?
  end

  test "only sends for email pending status" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")

    # Skipped
    user_level_skipped = create(:user_level, user: user, level: level, completed_at: Time.current, email_status: :skipped)
    refute_email_sent(user_level_skipped)

    # Sent
    level_sent = create(:level, slug: "level-2")
    user_level_sent = create(:user_level, user: user, level: level_sent, completed_at: Time.current, email_status: :sent)
    refute_email_sent(user_level_sent)

    # Failed
    level_failed = create(:level, slug: "level-3")
    user_level_failed = create(:user_level, user: user, level: level_failed, completed_at: Time.current, email_status: :failed)
    refute_email_sent(user_level_failed)

    # Pending
    level_pending = create(:level, slug: "level-4")
    create(:email_template, slug: "level-4", locale: "en")
    user_level_pending = create(:user_level, user: user, level: level_pending, completed_at: Time.current, email_status: :pending)
    assert_email_sent(user_level_pending)
  end

  test "prevents duplicate sending with locking" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    # Simulate concurrent calls
    call_count = 0
    threads = Array.new(2) do
      Thread.new do
        User::SendEmail.(user_level) do
          call_count += 1
        end
      end
    end
    threads.each(&:join)

    # Only one thread should have actually sent
    assert_equal 1, call_count
    assert user_level.reload.email_sent?
  end

  test "returns true when email is sent" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    result = User::SendEmail.(user_level) {}

    assert result
  end

  test "returns false when email is skipped" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    # No template exists
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    result = User::SendEmail.(user_level) {}

    refute result
  end

  test "raises error when no block is given" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    user_level = create(:user_level, user: user, level: level, completed_at: Time.current)

    assert_raises(RuntimeError, "Block must be given for sending") do
      User::SendEmail.(user_level)
    end
  end

  private
  def assert_email_sent(emailable)
    called = false
    sending_block = proc { called = true }

    sent = User::SendEmail.(emailable, &sending_block)

    assert sent, "Expected email to be sent"
    assert called, "Expected sending block to be called"
  end

  def refute_email_sent(emailable)
    sending_block = proc { flunk "Expected sending block not to be called" }

    sent = User::SendEmail.(emailable, &sending_block)

    refute sent, "Expected email not to be sent"
  end
end
