class CreateExerciseSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :exercise_submissions do |t|
      t.references :context, polymorphic: true, null: false
      t.string :uuid, null: false

      t.timestamps
    end
    add_index :exercise_submissions, :uuid, unique: true
  end
end
