class CreateLevels < ActiveRecord::Migration[8.0]
  def change
    create_table :levels do |t|
      t.references :course, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.integer :position, null: false

      # Milestone fields
      t.text :milestone_summary, null: false
      t.text :milestone_content, null: false
      t.text :milestone_email_subject, null: false, default: ""
      t.text :milestone_email_content_markdown, null: false, default: ""
      t.string :milestone_email_image_url, null: false, default: ""

      t.timestamps
    end
    add_index :levels, :slug, unique: true
    add_index :levels, %i[course_id position], unique: true
  end
end
