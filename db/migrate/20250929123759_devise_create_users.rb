# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      ## User profile
      t.string :name
      t.string :handle, null: false
      t.string :locale, null: false, default: "en"
      t.string :avatar_url

      ## OAuth fields
      t.string :google_id
      t.string :provider

      ## Admin access
      t.boolean :admin, null: false, default: false

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :handle,               unique: true
    add_index :users, :google_id,            unique: true
  end
end
