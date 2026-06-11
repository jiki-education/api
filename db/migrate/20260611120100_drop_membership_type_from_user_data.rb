class DropMembershipTypeFromUserData < ActiveRecord::Migration[8.1]
  def up
    remove_index :user_data, :membership_type, name: "index_user_data_on_membership_type"
    remove_column :user_data, :membership_type
  end

  def down
    add_column :user_data, :membership_type, :string, default: "standard", null: false
    add_index :user_data, :membership_type, name: "index_user_data_on_membership_type"
  end
end
