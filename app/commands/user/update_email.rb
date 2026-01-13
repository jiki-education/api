class User
  class UpdateEmail
    include Mandate

    initialize_with :user, :new_email

    def call
      # With Devise reconfirmable enabled, updating email will:
      # 1. Store the new email in unconfirmed_email
      # 2. Keep the current email in email field
      # 3. Send confirmation instructions to the new address
      # 4. Move unconfirmed_email to email once confirmed
      user.update!(email: new_email)
    end
  end
end
