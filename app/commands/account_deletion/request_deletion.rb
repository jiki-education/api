class AccountDeletion::RequestDeletion
  include Mandate

  initialize_with :user

  def call
    token = AccountDeletion::CreateDeletionToken.(user)
    confirmation_url = "#{Jiki.config.frontend_base_url}/delete-account/confirm?token=#{token}"

    AccountMailer.account_deletion_confirmation(user, confirmation_url:).deliver_later
  end
end
