require "test_helper"

# NOTE: Prerequisite job feature tests are skipped - not yet implemented for Solid Queue
# The feature was ported from Sidekiq but is not currently used in the codebase.
# Will implement when needed using Solid Queue's job querying API.

class MandateJobTest < ActiveJob::TestCase
  # Test command that succeeds
  class TestSuccessCommand
    include Mandate

    initialize_with :value

    def call
      "Success: #{value}"
    end
  end

  # Test command that uses requeue_job!
  class TestRequeueCommand
    include Mandate

    initialize_with :should_requeue

    def call
      requeue_job!(30) if should_requeue
      "Completed"
    end
  end

  # Test command with guard_against_deserialization_errors?
  class TestGuardedCommand
    include Mandate

    def call
      "Guarded"
    end

    def guard_against_deserialization_errors?
      false
    end
  end

  # Test command that raises an error
  class TestErrorCommand
    include Mandate

    def call
      raise StandardError, "Test error"
    end
  end

  test "successfully executes a Mandate command" do
    result = MandateJob.perform_now("MandateJobTest::TestSuccessCommand", "test_value")
    assert_equal "Success: test_value", result
  end

  test "passes mixed positional and keyword arguments" do
    # Test that both styles work through the job
    result = MandateJob.perform_now("MandateJobTest::TestSuccessCommand", "positional_value")
    assert_equal "Success: positional_value", result
  end

  test "handles requeue_job! and re-enqueues with wait time" do
    # Execute job which will call requeue_job!(30)
    travel_to Time.current do
      expected_time = 30.seconds.from_now

      MandateJob.perform_now("MandateJobTest::TestRequeueCommand", true)

      # Verify job was enqueued
      enqueued_job = enqueued_jobs.last
      assert_equal "MandateJob", enqueued_job[:job].name
      assert_equal ["MandateJobTest::TestRequeueCommand", true], enqueued_job[:args][0..1]
      assert_equal "default", enqueued_job[:queue]

      # Verify wait time matches the requeue_job! parameter (30 seconds)
      assert_in_delta expected_time.to_f, enqueued_job[:at].to_f, 1
    end
  end

  test "completes normally when requeue is not triggered" do
    result = MandateJob.perform_now("MandateJobTest::TestRequeueCommand", false)
    assert_equal "Completed", result
  end

  test "prerequisite jobs: proceeds when prereq_jobs is nil" do
    result = MandateJob.perform_now("MandateJobTest::TestSuccessCommand", "test", prereq_jobs: nil)
    assert_equal "Success: test", result
  end

  test "prerequisite jobs: proceeds when prereq_jobs is empty" do
    result = MandateJob.perform_now("MandateJobTest::TestSuccessCommand", "test", prereq_jobs: [])
    assert_equal "Success: test", result
  end

  # TODO: Re-enable when Solid Queue prerequisite job checking is implemented
  test "prerequisite jobs: blocks when prereq job is in queue" do
    skip("Solid Queue implementation pending")
    # Create mocks
    queue_mock = mock
    job_in_queue = mock

    # Setup expectations - when job is in queue, retry set is not checked
    queue_mock.expects(:find_job).with("prereq_job_123").returns(job_in_queue)

    # Stub the Sidekiq classes
    Sidekiq::Queue.expects(:new).with("default").returns(queue_mock)
    # RetrySet.new is never called because queue returns a job (short-circuit)

    error = assert_raises MandateJob::PreqJobNotFinishedError do
      MandateJob.perform_now(
        "MandateJobTest::TestSuccessCommand",
        "test",
        prereq_jobs: [{ job_id: "prereq_job_123", queue_name: "default" }]
      )
    end

    assert_match(/Unfinished job: prereq_job_123/, error.to_s)
  end

  test "prerequisite jobs: blocks when prereq job is in retry set" do
    skip("Solid Queue implementation pending")
    # Create mocks
    queue_mock = mock
    retry_set_mock = mock
    job_in_retry = mock

    # Setup expectations
    queue_mock.expects(:find_job).with("prereq_job_456").returns(nil)
    retry_set_mock.expects(:find_job).with("prereq_job_456").returns(job_in_retry)

    # Stub the Sidekiq classes
    Sidekiq::Queue.expects(:new).with("default").returns(queue_mock)
    Sidekiq::RetrySet.expects(:new).returns(retry_set_mock)

    error = assert_raises MandateJob::PreqJobNotFinishedError do
      MandateJob.perform_now(
        "MandateJobTest::TestSuccessCommand",
        "test",
        prereq_jobs: [{ job_id: "prereq_job_456", queue_name: "default" }]
      )
    end

    assert_match(/Unfinished job: prereq_job_456/, error.to_s)
  end

  test "prerequisite jobs: proceeds when prereq jobs are complete" do
    skip("Solid Queue implementation pending")
    # Create mocks that return nil (job not found)
    queue_mock = mock
    retry_set_mock = mock

    # Setup expectations
    queue_mock.expects(:find_job).with("completed_job_789").returns(nil)
    retry_set_mock.expects(:find_job).with("completed_job_789").returns(nil)

    # Stub the Sidekiq classes
    Sidekiq::Queue.expects(:new).with("default").returns(queue_mock)
    Sidekiq::RetrySet.expects(:new).returns(retry_set_mock)

    result = MandateJob.perform_now(
      "MandateJobTest::TestSuccessCommand",
      "test",
      prereq_jobs: [{ job_id: "completed_job_789", queue_name: "default" }]
    )

    assert_equal "Success: test", result
  end

  test "deserialization guard: respects guard_against_deserialization_errors?" do
    job = MandateJob.new
    job.perform("MandateJobTest::TestGuardedCommand")

    refute job.guard_against_deserialization_errors?
  end

  test "deserialization guard: defaults to true when method not defined" do
    job = MandateJob.new
    job.perform("MandateJobTest::TestSuccessCommand", "test")

    assert job.guard_against_deserialization_errors?
  end

  test "job fails when Mandate command raises unhandled exception" do
    error = assert_raises StandardError do
      MandateJob.perform_now("MandateJobTest::TestErrorCommand")
    end

    assert_equal "Test error", error.message
  end

  test "requeue preserves all arguments" do
    assert_enqueued_jobs 1 do
      MandateJob.perform_now("MandateJobTest::TestRequeueCommand", true)
    end
  end

  test "requeue preserves prerequisite jobs" do
    skip("Solid Queue implementation pending")
    # When a job with prerequisites requeues itself, prereq_jobs should be preserved
    prereq_jobs = [{ job_id: "prereq_123", queue_name: "default" }]

    # Mock the prerequisite check to pass
    queue_mock = mock
    retry_set_mock = mock
    queue_mock.expects(:find_job).with("prereq_123").returns(nil)
    retry_set_mock.expects(:find_job).with("prereq_123").returns(nil)
    Sidekiq::Queue.expects(:new).with("default").returns(queue_mock)
    Sidekiq::RetrySet.expects(:new).returns(retry_set_mock)

    # Execute the job which should requeue itself
    MandateJob.perform_now(
      "MandateJobTest::TestRequeueCommand",
      true,
      prereq_jobs:
    )

    # Check that the requeued job has prereq_jobs preserved
    enqueued_job = enqueued_jobs.last
    assert_equal "MandateJob", enqueued_job[:job].name
    assert_equal ["MandateJobTest::TestRequeueCommand", true], enqueued_job[:args][0..1]

    # Verify prereq_jobs is in the kwargs hash (ActiveJob uses string keys after serialization)
    kwargs = enqueued_job[:args].last
    assert_kind_of Hash, kwargs
    assert_includes kwargs, "prereq_jobs"

    # Verify the prerequisite job data is preserved
    requeued_prereqs = kwargs["prereq_jobs"]
    assert_equal 1, requeued_prereqs.length
    assert_equal "prereq_123", requeued_prereqs.first["job_id"]
    assert_equal "default", requeued_prereqs.first["queue_name"]
  end

  test "prerequisite jobs: handles multiple prerequisites" do
    skip("Solid Queue implementation pending")
    # Create mocks for 3 prerequisite jobs
    queue_mock = mock
    retry_set_mock = mock

    # All 3 prerequisite jobs are complete (not found in queue or retry set)
    queue_mock.expects(:find_job).with("job_1").returns(nil)
    retry_set_mock.expects(:find_job).with("job_1").returns(nil)
    queue_mock.expects(:find_job).with("job_2").returns(nil)
    retry_set_mock.expects(:find_job).with("job_2").returns(nil)
    queue_mock.expects(:find_job).with("job_3").returns(nil)
    retry_set_mock.expects(:find_job).with("job_3").returns(nil)

    Sidekiq::Queue.expects(:new).with("default").returns(queue_mock).times(3)
    Sidekiq::RetrySet.expects(:new).returns(retry_set_mock).times(3)

    result = MandateJob.perform_now(
      "MandateJobTest::TestSuccessCommand",
      "test",
      prereq_jobs: [
        { job_id: "job_1", queue_name: "default" },
        { job_id: "job_2", queue_name: "default" },
        { job_id: "job_3", queue_name: "default" }
      ]
    )

    assert_equal "Success: test", result
  end
end
