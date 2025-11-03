class CreateEmailTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :email_templates do |t|
      t.integer :type, null: false
      t.string :slug
      t.string :locale, null: false
      t.text :subject, null: false
      t.text :body_mjml, null: false
      t.text :body_text, null: false

      t.timestamps
    end

    add_index :email_templates, %i[type slug locale], unique: true, name: "index_email_templates_on_type_and_slug_and_locale"
  end
end
