class AddCountryCodeToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :country_code, :string, limit: 2
  end
end
