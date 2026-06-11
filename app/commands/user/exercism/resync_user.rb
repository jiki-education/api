class User::Exercism::ResyncUser
  include Mandate

  queue_as :default

  initialize_with :user

  def call
    return if user.exercism_id.blank?

    status = Exercism::FetchUserStatus.(user.exercism_id)

    User::Exercism::ReconcileEntitlements.(
      user,
      is_insider: status['is_insider'],
      is_bootcamp_member: status['is_bootcamp_member']
    )
  end
end
