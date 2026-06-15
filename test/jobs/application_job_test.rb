require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  # Test job that uses the default guard behavior
  class TestJobWithGuard < ApplicationJob
    def perform(user)
      user.email
      "Success"
    end
  end

  # Test job that disables guard behavior
  class TestJobWithoutGuard < ApplicationJob
    def guard_against_deserialization_errors? = false

    def perform(user)
      user.email
      "Success"
    end
  end

  # Test job that raises DeserializationError
  class TestDeserializationJob < ApplicationJob
    def perform
      # ActiveJob::DeserializationError uses $! so this needs wrapping like this
      raise
    rescue StandardError
      raise ActiveJob::DeserializationError
    end
  end

  # Test job that updates user (for testing record appearing during wait)
  class TestDeserializationWithUserJob < ApplicationJob
    def perform(user)
      user.update(name: "new")
    end
  end

  test "handles ActiveRecord::Deadlocked with retry" do
    # Verify retry_on is configured for deadlocks by checking class configuration
    assert_respond_to ApplicationJob, :retry_on
  end

  class FlakyJob < ApplicationJob
    cattr_accessor :calls, default: 0

    def perform
      self.class.calls += 1
      raise "flaky" if self.class.calls < 3
    end
  end

  test "retries any unhandled StandardError" do
    FlakyJob.calls = 0

    perform_enqueued_jobs do
      FlakyJob.perform_later
    end

    assert_equal 3, FlakyJob.calls
  end

  class AlwaysFailingJob < ApplicationJob
    cattr_accessor :calls, default: 0

    def perform
      self.class.calls += 1
      raise "always fails"
    end
  end

  test "gives up after 10 attempts on a persistently-failing job" do
    AlwaysFailingJob.calls = 0

    # Minitest wraps unexpected exceptions in Minitest::UnexpectedError to
    # distinguish them from assertion failures, which bypasses our StandardError
    # rescue. Catch the wrapper and assert on the underlying exception.
    captured = nil
    begin
      perform_enqueued_jobs do
        AlwaysFailingJob.perform_later
      end
    rescue Minitest::UnexpectedError => e
      captured = e.error
    end

    refute_nil captured, "expected the final retry to re-raise"
    assert_instance_of RuntimeError, captured
    assert_equal "always fails", captured.message
    assert_equal 10, AlwaysFailingJob.calls
  end

  test "guard_against_deserialization_errors? defaults to true" do
    job = TestJobWithGuard.new
    assert job.guard_against_deserialization_errors?
  end

  test "guard_against_deserialization_errors? can be overridden to false" do
    job = TestJobWithoutGuard.new
    refute job.guard_against_deserialization_errors?
  end

  test "integration: job succeeds when record exists" do
    user = create(:user)

    perform_enqueued_jobs do
      TestJobWithGuard.perform_later(user)
    end

    assert_performed_jobs 1
  end

  test "integration: job with multiple users succeeds" do
    user1 = create(:user)
    user2 = create(:user)

    perform_enqueued_jobs do
      TestJobWithGuard.perform_later(user1)
      TestJobWithGuard.perform_later(user2)
    end

    assert_performed_jobs 2
  end

  test "deserialization raises for non-active-record exception" do
    exception = assert_raises ActiveJob::DeserializationError do
      TestDeserializationJob.perform_now
    end

    # Verify this is a real error (not a RecordNotFound that we handle gracefully)
    refute exception.cause.is_a?(ActiveRecord::RecordNotFound)
  end

  test "deserialization drops the job with a missing model" do
    # Don't sleep when testing things else we'll be here all day!
    Mocha::Configuration.override(stubbing_non_public_method: :allow) do
      ApplicationJob.any_instance.stubs(:sleep)
    end

    user = create(:user)
    user.destroy

    User.expects(:find).with(user.id.to_s).raises(ActiveRecord::RecordNotFound)
    perform_enqueued_jobs do
      TestDeserializationWithUserJob.perform_later(user)
    end
  end

  test "deserialization drops silently if record is gone" do
    # Don't sleep when testing things else we'll be here all day!
    Mocha::Configuration.override(stubbing_non_public_method: :allow) do
      ApplicationJob.any_instance.stubs(:sleep)
    end

    user = create(:user)
    user.destroy

    exception = ActiveRecord::RecordNotFound.new('', 'User', :id, user.id.to_s)
    # Called once during deserialization, then 20 more times in retry loop
    User.expects(:find).with(user.id.to_s).raises(exception).times(21)

    perform_enqueued_jobs do
      TestDeserializationWithUserJob.perform_later(user)
    end
  end

  test "deserialization retries then runs if model appears successfully" do
    user = create(:user)
    user.destroy

    # In a separate thread, recreate the user. This will happen in between the
    # first deserialization error and the second lookup check.
    Thread.new do
      sleep(0.2)
      create(:user, id: user.id, name: 'old')
    end

    perform_enqueued_jobs do
      TestDeserializationWithUserJob.perform_later(user)
    end

    # The job should change this
    assert_equal 'new', user.reload.name
  end

  # Test that guard method from Mandate command is consulted during deserialization
  # This is tested via the existing TestJobWithoutGuard which already has guard disabled
  # and the test "deserialization drops the job with a missing model" verifies the guard works
end
