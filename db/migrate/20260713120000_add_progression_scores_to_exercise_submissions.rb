class AddProgressionScoresToExerciseSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :exercise_submissions, :progression_scores, :jsonb
  end
end
