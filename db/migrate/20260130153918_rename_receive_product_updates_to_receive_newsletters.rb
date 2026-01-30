class RenameReceiveProductUpdatesToReceiveNewsletters < ActiveRecord::Migration[8.1]
  def change
    rename_column :user_data, :receive_product_updates, :receive_newsletters
  end
end
