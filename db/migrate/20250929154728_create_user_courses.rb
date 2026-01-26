class CreateUserCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :user_courses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :current_user_level, null: true, foreign_key: { to_table: :user_levels }
      t.string :language
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :user_courses, %i[user_id course_id], unique: true
  end
end
