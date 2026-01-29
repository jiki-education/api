class AccountDeletion::ConfirmDeletion
  include Mandate

  initialize_with :token

  def call
    user = AccountDeletion::ValidateDeletionToken.(token)
    User::Destroy.(user)
  end
end
