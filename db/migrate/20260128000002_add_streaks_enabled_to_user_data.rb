class AddStreaksEnabledToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :streaks_enabled, :boolean, default: false, null: false
  end
end
