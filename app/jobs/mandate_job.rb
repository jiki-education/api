class MandateJob < ApplicationJob
  class MandateJobNeedsRequeuing < RuntimeError
    attr_reader :wait

    def initialize(wait)
      @wait = wait
      super(nil)
    end
  end

  class PreqJobNotFinishedError < RuntimeError
    def initialize(job_id)
      @job_id = job_id
      super(nil)
    end

    def to_s
      "Unfinished job: #{job_id}"
    end

    private
    attr_reader :job_id
  end

  def perform(cmd, *args, **kwargs)
    # Extract and validate prerequisite jobs before deletion
    # We need to preserve this for requeuing in case of rate limiting
    prereq_jobs_value = kwargs.delete(:prereq_jobs)
    __guard_prereq_jobs__!(prereq_jobs_value)

    instance = cmd.constantize.new(*args, **kwargs)
    instance.define_singleton_method(:requeue_job!) { |wait| raise MandateJobNeedsRequeuing, wait }
    self.define_singleton_method :guard_against_deserialization_errors? do
      return true unless instance.respond_to?(:guard_against_deserialization_errors?)

      instance.guard_against_deserialization_errors?
    end

    instance.()
  rescue MandateJobNeedsRequeuing => e
    # Preserve prerequisite jobs when requeuing to maintain dependency chain
    requeue_kwargs = kwargs.merge(wait: e.wait)
    requeue_kwargs[:prereq_jobs] = prereq_jobs_value if prereq_jobs_value.present?

    cmd.constantize.defer(*args, **requeue_kwargs)
  end

  def __guard_prereq_jobs__!(prereq_jobs)
    return unless prereq_jobs.present?

    # TODO: Implement prerequisite job checking for Solid Queue
    # This feature was ported from Sidekiq but is not currently used in the codebase.
    # When needed, implement using Solid Queue's job querying API:
    # - SolidQueue::Job.where(active_job_id: jid).exists?
    # - Check both ready and failed execution tables
    #
    # Original Sidekiq implementation (for reference):
    # prereq_jobs.each do |job|
    #   jid = job[:job_id]
    #   if Sidekiq::Queue.new(job[:queue_name]).find_job(jid) ||
    #      Sidekiq::RetrySet.new.find_job(jid)
    #     raise PreqJobNotFinishedError, jid
    #   end
    # end

    Rails.logger.warn("Prerequisite job checking not yet implemented for Solid Queue")
  end
end
