class AddExercismIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :exercism_id, :string
    add_index :users, :exercism_id, unique: true
  end
end
