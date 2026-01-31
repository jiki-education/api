require "test_helper"

class SES::HandleEmailComplaintTest < ActiveSupport::TestCase
  test "handles spam complaint and unsubscribes from marketing" do
    user = create(:user)

    event = {
      'complaint' => {
        'complaintFeedbackType' => 'abuse',
        'complainedRecipients' => [
          {
            'emailAddress' => user.email
          }
        ]
      }
    }

    SES::HandleEmailComplaint.(event)

    user.reload
    refute user.data.may_receive_emails?
    assert_equal 'abuse', user.data.email_complaint_type
    refute_nil user.data.email_complaint_at
  end

  test "handles multiple complained recipients" do
    user1 = create(:user)
    user2 = create(:user)

    event = {
      'complaint' => {
        'complaintFeedbackType' => 'abuse',
        'complainedRecipients' => [
          {
            'emailAddress' => user1.email
          },
          {
            'emailAddress' => user2.email
          }
        ]
      }
    }

    SES::HandleEmailComplaint.(event)

    user1.reload
    user2.reload
    refute user1.data.may_receive_emails?
    refute user2.data.may_receive_emails?
  end

  test "handles different complaint types" do
    # Test each complaint type separately (one event per type)
    # Pause N+1 detection since each iteration is a separate webhook event
    Prosopite.pause
    %w[abuse fraud virus].each do |complaint_type|
      user = create(:user)

      event = {
        'complaint' => {
          'complaintFeedbackType' => complaint_type,
          'complainedRecipients' => [
            {
              'emailAddress' => user.email
            }
          ]
        }
      }

      SES::HandleEmailComplaint.(event)

      user.reload
      refute user.data.may_receive_emails?
      assert_equal complaint_type, user.data.email_complaint_type
    end
    Prosopite.resume
  end

  test "handles complaint for non-existent user gracefully" do
    event = {
      'complaint' => {
        'complaintFeedbackType' => 'abuse',
        'complainedRecipients' => [
          {
            'emailAddress' => 'nonexistent@example.com'
          }
        ]
      }
    }

    # Should not raise error even if user doesn't exist
    assert_nothing_raised do
      SES::HandleEmailComplaint.(event)
    end
  end
end
