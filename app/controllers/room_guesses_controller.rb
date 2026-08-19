class RoomGuessesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_room

  # POST /rooms/:room_id/guesses
  # Processa o chute de um jogador numa rodada de sala. Não confia no
  # relógio do cliente para o tempo de resposta — usa room_round.started_at,
  # que é o análogo, em sala, do session[:round_started_at] do jogo solo.
  def create
    unless @room.room_players.exists?(user: current_user)
      redirect_to new_room_path, alert: "Você não faz parte dessa sala."
      return
    end

    room_round = @room.current_room_round

    unless @room.in_progress? && room_round&.active?
      redirect_to room_path(@room), alert: "Essa rodada já terminou."
      return
    end

    time_seconds = [ (Time.current - room_round.started_at).to_i, 1 ].max

    game_round = current_user.game_rounds.build(
      country: room_round.country,
      room_round: room_round,
      guessed_lat: params[:lat].to_f,
      guessed_lng: params[:lng].to_f,
      time_seconds: time_seconds
    )

    if game_round.save
      @room.touch_activity!

      if room_round.due_for_finalization?
        room_round.finalize!
        broadcast_results(@room)
      else
        broadcast_progress(room_round)
      end
    else
      flash[:alert] = "Erro ao registrar chute: #{game_round.errors.full_messages.join(', ')}"
    end

    redirect_to room_path(@room)
  end

  private

  def set_room
    @room = Room.find(params[:room_id])
  end

  def broadcast_progress(room_round)
    @room.broadcast_replace_to(@room, target: "room_progress", partial: "rooms/progress",
      locals: { room_round: room_round })
  end

  def broadcast_results(room)
    room.broadcast_replace_to(room, target: "room_body", partial: "rooms/results",
      locals: { room: room, room_round: room.current_room_round })
  end
end
