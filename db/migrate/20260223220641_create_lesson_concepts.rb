class CreateLessonConcepts < ActiveRecord::Migration[8.1]
  def change
    create_table :lesson_concepts do |t|
      t.references :lesson, null: false, foreign_key: true
      t.references :concept, null: false, foreign_key: true

      t.timestamps
    end

    add_index :lesson_concepts, %i[lesson_id concept_id], unique: true
  end
end
