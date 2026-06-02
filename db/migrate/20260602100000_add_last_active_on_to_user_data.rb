class AddLastActiveOnToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :last_active_on, :date
  end
end
