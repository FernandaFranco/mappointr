class RoomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_room, only: [ :show, :start, :advance ]
  before_action :expire_if_stale!, only: [ :show ]
  before_action :require_membership!, only: [ :show, :start, :advance ]

  # GET /rooms/new
  def new
    @room = Room.new
  end

  # POST /rooms
  # Cria a sala e já entra nela como o primeiro jogador (host)
  def create
    @room = Room.new(room_params)
    @room.host = current_user

    if @room.save
      @room.room_players.create!(user: current_user)
      redirect_to room_path(@room)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /rooms/join
  # Entra em uma sala existente a partir do código compartilhado
  def join
    room = Room.find_by(code: params[:code].to_s.strip.upcase)

    if room.nil?
      redirect_to new_room_path, alert: "Código não encontrado."
    elsif room.room_players.exists?(user: current_user)
      redirect_to room_path(room)
    elsif !room.waiting?
      redirect_to new_room_path, alert: "Essa sala já começou ou terminou."
    elsif room.full?
      redirect_to new_room_path, alert: "Essa sala está cheia."
    else
      room.room_players.create!(user: current_user)
      room.touch_activity!
      broadcast_lobby(room)
      redirect_to room_path(room)
    end
  end

  # GET /rooms/:id
  def show
  end

  # POST /rooms/:id/start
  # Só o host pode iniciar, e só depois de MIN_PLAYERS terem entrado
  def start
    if @room.host_id != current_user.id
      redirect_to room_path(@room), alert: "Só quem criou a sala pode iniciar."
      return
    end

    unless @room.waiting?
      redirect_to room_path(@room)
      return
    end

    unless @room.enough_players_to_start?
      redirect_to room_path(@room), alert: "Precisa de pelo menos #{Room::MIN_PLAYERS} jogadores para começar."
      return
    end

    @room.update!(status: :in_progress)
    start_next_round!(@room)
    @room.touch_activity!
    broadcast_round(@room)
    redirect_to room_path(@room)
  end

  # POST /rooms/:id/advance
  # Chamado (repetidamente) pelo cliente via Stimulus para avançar a sala.
  # Não confia no timing do cliente: recalcula tudo a partir do estado no
  # banco antes de agir, então é seguro chamar a qualquer momento e de
  # múltiplas abas ao mesmo tempo.
  def advance
    @room.with_lock do
      round = @room.current_room_round

      if round&.due_for_finalization?
        round.finalize!
        broadcast_results(@room)
      elsif round&.finished? && Time.current >= round.ended_at + Room::REVEAL_PAUSE_SECONDS
        advance_past_reveal!(@room)
      end
    end

    @room.touch_activity!
    head :no_content
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def require_membership!
    return if @room.room_players.exists?(user: current_user)
    redirect_to new_room_path, alert: "Você não faz parte dessa sala."
  end

  def expire_if_stale!
    @room.update!(status: :expired) if @room.stale?
  end

  def room_params
    permitted = params.require(:room).permit(:total_rounds, :round_duration_seconds, :difficulty)
    permitted[:difficulty] = permitted[:difficulty].presence
    permitted
  end

  def start_next_round!(room)
    country = Country.random(difficulty: room.difficulty)
    round_number = room.current_round_number + 1
    room_round = RoomRound.create!(room: room, country: country, round_number: round_number, started_at: Time.current)
    room.update!(current_round_number: round_number, current_room_round: room_round)
  end

  def advance_past_reveal!(room)
    if room.current_round_number >= room.total_rounds
      room.update!(status: :finished)
      broadcast_leaderboard(room)
    else
      start_next_round!(room)
      broadcast_round(room)
    end
  end

  # Substitui a sala de espera inteira (não só a lista de jogadores): quem
  # entra pode fazer a sala cruzar o limiar de MIN_PLAYERS, e a visibilidade
  # do botão "Iniciar jogo" depende desse total — não só do que dá pra
  # atualizar sostituindo o `id="room_players"` sozinho.
  def broadcast_lobby(room)
    room.broadcast_replace_to(room, target: "room_body", partial: "rooms/waiting_room", locals: { room: room })
  end

  def broadcast_round(room)
    room.broadcast_replace_to(room, target: "room_body", partial: "rooms/round",
      locals: { room: room, room_round: room.current_room_round })
  end

  def broadcast_results(room)
    room.broadcast_replace_to(room, target: "room_body", partial: "rooms/results",
      locals: { room: room, room_round: room.current_room_round })
  end

  def broadcast_leaderboard(room)
    room.broadcast_replace_to(room, target: "room_body", partial: "rooms/leaderboard", locals: { room: room })
  end
end
