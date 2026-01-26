class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :courses, :slug, unique: true
    add_index :courses, :position, unique: true
  end
end
