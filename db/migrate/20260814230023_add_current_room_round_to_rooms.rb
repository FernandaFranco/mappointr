class AddCurrentRoomRoundToRooms < ActiveRecord::Migration[7.2]
  def change
    add_reference :rooms, :current_room_round, null: true, foreign_key: { to_table: :room_rounds }
  end
end
