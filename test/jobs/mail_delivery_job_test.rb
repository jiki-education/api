require "test_helper"

class MailDeliveryJobTest < ActiveJob::TestCase
  test "is configured as ActionMailer's delivery job" do
    assert_equal MailDeliveryJob, ActionMailer::Base.delivery_job
  end

  test "retries on Aws::Errors::MissingCredentialsError instead of failing" do
    user = create(:user)
    OnboardingMailer.stubs(:community).raises(Aws::Errors::MissingCredentialsError)

    assert_enqueued_with(job: MailDeliveryJob) do
      MailDeliveryJob.perform_now("OnboardingMailer", "community", "deliver_now", args: [user])
    end
  end

  test "does not retry other errors" do
    user = create(:user)
    OnboardingMailer.stubs(:community).raises(RuntimeError, "boom")

    assert_no_enqueued_jobs do
      assert_raises(RuntimeError) do
        MailDeliveryJob.perform_now("OnboardingMailer", "community", "deliver_now", args: [user])
      end
    end
  end
end
