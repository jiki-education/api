class AddSignupAttributionToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :signup_attribution, :jsonb
  end
end
