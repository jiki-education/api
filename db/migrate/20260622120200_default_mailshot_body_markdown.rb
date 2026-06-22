class DefaultMailshotBodyMarkdown < ActiveRecord::Migration[8.1]
  def change
    # Allow drafts to be created without a body; presence is enforced at send time.
    change_column_default :mailshots, :body_markdown, from: nil, to: ""
  end
end
