class CreateAssistantConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :context, polymorphic: true, null: false
      t.json :messages, null: false, default: []
      t.timestamps
    end

    add_index :assistant_conversations, [:user_id, :context_type, :context_id],
      unique: true,
      name: 'index_assistant_conversations_on_user_and_context'
  end
end
