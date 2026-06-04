class User::SeenFlag < ApplicationRecord
  belongs_to :user

  validates :key, presence: true, length: { maximum: 100 }
end
