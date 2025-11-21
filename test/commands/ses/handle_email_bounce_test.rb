require "test_helper"
require_relative "../../../app/commands/ses/handle_email_bounce"

module SES
  class HandleEmailBounceTest < ActiveSupport::TestCase
    test "handles permanent bounce and marks email as invalid" do
      user = create(:user)

      event = {
        'bounce' => {
          'bounceType' => 'Permanent',
          'bouncedRecipients' => [
            {
              'emailAddress' => user.email,
              'diagnosticCode' => 'smtp; 550 5.1.1 user unknown'
            }
          ]
        }
      }

      SES::HandleEmailBounce.(event)

      user.reload
      refute user.data.email_valid?
      assert_equal 'smtp; 550 5.1.1 user unknown', user.data.email_bounce_reason
      refute_nil user.data.email_bounced_at
    end

    test "handles transient bounce without marking email as invalid" do
      user = create(:user)

      event = {
        'bounce' => {
          'bounceType' => 'Transient',
          'bouncedRecipients' => [
            {
              'emailAddress' => user.email,
              'diagnosticCode' => 'smtp; 452 4.2.2 mailbox full'
            }
          ]
        }
      }

      SES::HandleEmailBounce.(event)

      user.reload
      assert user.data.email_valid? # Email still valid after soft bounce
      assert_nil user.data.email_bounce_reason
      assert_nil user.data.email_bounced_at
    end

    test "handles multiple bounced recipients" do
      user1 = create(:user)
      user2 = create(:user)

      event = {
        'bounce' => {
          'bounceType' => 'Permanent',
          'bouncedRecipients' => [
            {
              'emailAddress' => user1.email,
              'diagnosticCode' => 'smtp; 550 5.1.1 user unknown'
            },
            {
              'emailAddress' => user2.email,
              'diagnosticCode' => 'smtp; 550 5.1.1 user unknown'
            }
          ]
        }
      }

      SES::HandleEmailBounce.(event)

      user1.reload
      user2.reload
      refute user1.data.email_valid?
      refute user2.data.email_valid?
    end

    test "handles bounce for non-existent user gracefully" do
      event = {
        'bounce' => {
          'bounceType' => 'Permanent',
          'bouncedRecipients' => [
            {
              'emailAddress' => 'nonexistent@example.com',
              'diagnosticCode' => 'smtp; 550 5.1.1 user unknown'
            }
          ]
        }
      }

      # Should not raise error even if user doesn't exist
      assert_nothing_raised do
        SES::HandleEmailBounce.(event)
      end
    end
  end
end
