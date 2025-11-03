class CreateAssistantConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :context_type, null: false
      t.string :context_identifier, null: false
      t.json :messages, null: false, default: []
      t.timestamps
    end

    add_index :assistant_conversations, [:user_id, :context_type, :context_identifier],
      unique: true,
      name: 'index_assistant_conversations_on_user_and_context'
    add_index :assistant_conversations, [:context_type, :context_identifier]
  end
end
