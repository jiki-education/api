class CreateConcepts < ActiveRecord::Migration[8.1]
  def change
    create_table :concepts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.text :content_markdown, null: false
      t.text :content_html, null: false
      t.string :standard_video_provider
      t.string :standard_video_id
      t.string :premium_video_provider
      t.string :premium_video_id
      t.bigint :unlocked_by_lesson_id
      t.references :parent_concept, null: true, foreign_key: { to_table: :concepts, on_delete: :nullify }
      t.integer :children_count, null: false, default: 0

      t.timestamps
    end

    add_index :concepts, :slug, unique: true
    add_foreign_key :concepts, :lessons, column: :unlocked_by_lesson_id
    add_index :concepts, :unlocked_by_lesson_id
  end
end
