class AddMilestoneFieldsToLevels < ActiveRecord::Migration[8.1]
  def change
    add_column :levels, :milestone_summary, :text, null: false, default: ''
    add_column :levels, :milestone_content, :text, null: false, default: ''
    add_column :levels, :milestone_email_subject, :text, null: false, default: ''
    add_column :levels, :milestone_email_content_markdown, :text, null: false, default: ''
    add_column :levels, :milestone_email_image_url, :string, null: false, default: ''
  end
end
