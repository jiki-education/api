class AddInternalToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :internal, :boolean, default: false, null: false
  end
end
