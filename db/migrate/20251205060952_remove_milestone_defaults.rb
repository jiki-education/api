class RemoveMilestoneDefaults < ActiveRecord::Migration[8.1]
  def change
    change_column_default :levels, :milestone_summary, from: '', to: nil
    change_column_default :levels, :milestone_content, from: '', to: nil
  end
end
