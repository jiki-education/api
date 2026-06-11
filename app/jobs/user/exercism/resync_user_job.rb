class User::Exercism::ResyncUserJob < ApplicationJob
  queue_as :default

  def perform(user)
    return unless user.exercism_id.present?

    status = Exercism::FetchUserStatus.(user.exercism_id)

    User::Exercism::ReconcileEntitlements.(
      user,
      is_insider: status['is_insider'],
      is_bootcamp_member: status['is_bootcamp_member']
    )
  end
end
