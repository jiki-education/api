class DeleteOrphanedLesson < ActiveRecord::Migration[8.0]
  def up
    Lesson.find_by(uuid: '7aa0cf6a-a70d-435c-900c-31a0c8556758')&.destroy!
  end

  def down
    # This migration is not reversible - the deleted lesson cannot be restored.
  end
end
