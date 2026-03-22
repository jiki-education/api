class RemoveIconFromBadges < ActiveRecord::Migration[8.1]
  def change
    remove_column :badges, :icon, :string, null: false
  end
end
