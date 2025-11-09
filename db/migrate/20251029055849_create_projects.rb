class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.string :exercise_slug, null: false
      t.bigint :unlocked_by_lesson_id, null: true

      t.timestamps
    end
    add_index :projects, :slug, unique: true
    add_index :projects, :unlocked_by_lesson_id
    add_foreign_key :projects, :lessons, column: :unlocked_by_lesson_id
  end
end
