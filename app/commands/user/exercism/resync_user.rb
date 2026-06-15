class User::Exercism::ResyncUser
  include Mandate

  queue_as :default

  initialize_with :user

  def call
    return if user.exercism_id.blank?

    User::Exercism::ReconcileEntitlements.(
      user,
      is_insider: status['is_insider'],
      is_bootcamp_member: status['is_bootcamp_member']
    )
  end

  private
  memoize
  def status = Exercism::FetchUserStatus.(user.exercism_id)
end
