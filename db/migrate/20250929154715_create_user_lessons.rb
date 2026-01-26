class CreateUserLessons < ActiveRecord::Migration[8.0]
  def change
    create_table :user_lessons do |t|
      t.references :user, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :user_lessons, %i[user_id lesson_id], unique: true
    add_index :user_lessons, %i[user_id course_id]
  end
end
