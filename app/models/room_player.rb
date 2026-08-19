class RoomPlayer < ApplicationRecord
  belongs_to :room
  belongs_to :user

  validates :user_id, uniqueness: { scope: :room_id }

  before_validation :set_joined_at, on: :create

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
