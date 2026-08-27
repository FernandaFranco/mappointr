class RoomsController < ApplicationController
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
    update_display_name!

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
    update_display_name!

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
    @room.start_next_round!
    @room.touch_activity!
    @room.broadcast_round
    redirect_to room_path(@room)
  end

  # POST /rooms/:id/advance
  # Chamado (repetidamente) pelo cliente via Stimulus para avançar a sala,
  # e também periodicamente por RoomSweepJob em background — cobre o caso
  # de todo mundo ter saído da página antes do fim da rodada. A lógica em
  # si (não confia no timing de quem chamou, recalcula tudo a partir do
  # banco) fica em Room#advance!, compartilhada entre controller e job.
  def advance
    @room.advance!
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

  # Deixa o jogador escolher um apelido ao entrar numa sala (a única hora em
  # que display_name aparece pra outras pessoas, ver rooms/_player_list e
  # afins). Ignora silenciosamente se vazio ou inválido (ex: passou de 30
  # caracteres) — um apelido ruim não deveria travar criar/entrar na sala.
  def update_display_name!
    return if params[:display_name].blank?

    current_user.update(display_name: params[:display_name])
  end

  # Substitui a sala de espera inteira (não só a lista de jogadores): quem
  # entra pode fazer a sala cruzar o limiar de MIN_PLAYERS, e a visibilidade
  # do botão "Iniciar jogo" depende desse total — não só do que dá pra
  # atualizar sostituindo o `id="room_players"` sozinho.
  def broadcast_lobby(room)
    room.broadcast_replace_to(room, target: "room_body", partial: "rooms/waiting_room", locals: { room: room })
  end
end
