class User::SendEmail
  include Mandate

  initialize_with :emailable, kind: nil

  # TODO: Move this into mandate!
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).(&block)
  end

  # This returns a boolean based on whether it succeeds or not
  def call
    raise "Block must be given for sending" unless block_given?

    # We start by doing checks to see if we should send based
    # on the state of the emailable. We hope to catch things
    # here to avoid locking
    return false unless pending?
    return false unless guard_needs_sending!

    # Do this first, so we can do it outside of the lock
    return false unless guard_user_wants_email!

    # TODO: (Required) Check for daily-batch preference

    # We now lock and recheck things. We do the rechecking in the locked
    # record to avoid race conditions.
    emailable.with_lock do
      return false unless pending?
      return false unless guard_needs_sending!

      yield

      mark_sent!

      true
    end
  end

  private
  def pending? = emailable.public_send(:"#{status_prefix}_pending?")
  def mark_sent! = emailable.public_send(:"#{status_prefix}_sent!")
  def mark_skipped! = emailable.public_send(:"#{status_prefix}_skipped!")
  def status_prefix = kind ? :"#{kind}_email" : :email

  def guard_needs_sending!
    return true if emailable.email_should_send?(kind)

    mark_skipped!
    false
  end

  def guard_user_wants_email!
    conditions = [
      has_affirmative_communication_preference?,
      user.may_receive_emails?
    ]

    return true if conditions.all?

    mark_skipped!
    false
  end

  def has_affirmative_communication_preference?
    pref_key = emailable.email_communication_preferences_key(kind)
    return true unless pref_key

    user.communication_preferences&.send(pref_key)
  end

  memoize
  delegate :user, to: :emailable
end
