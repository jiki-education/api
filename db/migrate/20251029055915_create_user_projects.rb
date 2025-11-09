class CreateUserProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :user_projects do |t|
      t.bigint :user_id, null: false
      t.bigint :project_id, null: false
      t.datetime :started_at, null: true
      t.datetime :completed_at, null: true

      t.timestamps
    end
    add_index :user_projects, [:user_id, :project_id], unique: true
    add_index :user_projects, :project_id
    add_foreign_key :user_projects, :users
    add_foreign_key :user_projects, :projects
  end
end
