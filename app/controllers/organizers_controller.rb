class OrganizersController < ApplicationController
  include ApplicationHelper
  before_action :set_organizer, only: [:show, :edit, :update, :destroy, :transfer, :guided_tour, :guidebooks, :external_events, :import_events, :profile_edit, :account, :account_edit, :bank_account_edit, :account_status, :guided_tour, :edit_guided_tour, :schedule, :clients, :confirm_account]
  before_action :authenticate_user!, :except => [:show, :index, :create]
  before_filter :check_if_organizer_admin, only: [:update, :manage, :transfer, :transfer_funds, :tos_acceptance, :tos_acceptance_confirm, :external_events, :import_events, :profile_edit, :account, :account_edit, :bank_account_edit, :account_status, :guided_tour, :edit_guided_tour, :schedule, :clients, :confirm_account]
  before_filter :check_if_super_admin, only: [:new, :edit, :invite, :send_invite]

  # GET /organizers
  # GET /organizers.json
  def index
    @organizers = Organizer.publisheds
  end

  # GET /organizers/1
  # GET /organizers/1.json
  def show
    if !!session[:follow]
      current_user.follow(@organizer)
      OrganizerMailer.new_follower(@organizer, current_user).deliver_now
      session[:follow] = nil
    end
  end

  def invite

  end

  def send_invite
    @invited = Organizer.find(params[:invited])
    if @invited
      @invited.update_attributes({:invite_token => SecureRandom.urlsafe_base64})
      OrganizerMailer.invite(@invited).deliver_now
      redirect_to invite_path, :notice => I18n.t('guide-invite-successfull')
    else
      redirect_to invite_path, :notice => I18n.t('guide-invite-fail')
    end
  end

  def accept_invite
    @organizer = Organizer.find(params[:id])
    if @organizer.try(:id)
      organizer_token = @organizer.try(:invite_token)
      if organizer_token == params[:token]
        if not user_signed_in?
          redirect_to new_user_session_path, :notice => @notice_message
        else
          if current_user == @organizer.user
            ContactMailer.notify("mensagem para o guia que recebeu o convite: Você já está associado a este perfil de guia").deliver_now
            redirect_to organizer_path(@organizer), :notice => "Você já está associado a este perfil de guia"
          else
            @organizer.user = current_user
            if @organizer.save
              ContactMailer.notify("mensagem para o guia que recebeu o convite: Sua conta de guia foi criada").deliver_now
              redirect_to organizer_path(@organizer), :notice => "Sua conta de guia foi criada"
            else
              ContactMailer.notify("mensagem para o guia que recebeu o convite: Tivemos problema ao associar seu perfil").deliver_now
              redirect_to organizer_path(@organizer), :notice => "Tivemos problema ao associar seu perfil"
            end
          end
        end
      else
        redirect_to root_path, :notice => "Convite inválido"
        return
      end
    else
      redirect_to new_user_session_path, :notice => "Não foi possível encontrar o seu perfil de guia"
      return
    end
  end

  # GET /organizers/new
  def new
    @organizer = Organizer.new
  end

  def guided_tour
    @guided_tour = @organizer.tours.new
    @opened = flash[:opened] || false
    @cats = ["Esportes e aventura", "Trilhas e travessias", "Relax", "Família", "Geek", "Gastronomia", "Urbano", "Cultura"]
  end

  def edit_guidebook
    @guided_tour = Guidebook.find(params[:guidebook])
    @organizer = Organizer.find(params[:id])
    @cats = ["Esportes e aventura", "Trilhas e travessias", "Relax", "Família", "Geek", "Gastronomia", "Urbano", "Cultura"]
    @current_category_name = Category.find(@guided_tour.category_id).name rescue nil
  end

  def guidebooks
    @guided_tour = @organizer.guidebooks.new
    @opened = flash[:opened] || false
    @cats = ["Esportes e aventura", "Trilhas e travessias", "Relax", "Família", "Geek", "Gastronomia", "Urbano", "Cultura"]
  end

  def edit_guided_tour
    @guided_tour = Tour.find(params[:tour])
    @organizer = Organizer.find(params[:id])
    @cats = ["Esportes e aventura", "Trilhas e travessias", "Relax", "Família", "Geek", "Gastronomia", "Urbano", "Cultura"]
    @current_category_name = Category.find(@guided_tour.category_id).name rescue nil
  end

  def profile_edit

  end

  # GET /organizers/1/edit
  def edit

  end

  # POST /organizers
  # POST /organizers.json
  def create

    @organizer = Organizer.new(organizer_params.except! 'type_of_user', 'password', 'password_confirmation')

    if !organizer_params[:user_id] && organizer_params[:type_of_user] === 'organizer'
      sign_up_params = {
          name: organizer_params[:name],
          email: organizer_params[:email],
          password: organizer_params[:password],
          password_confirmation: organizer_params[:password_confirmation],
          type_of_user: organizer_params[:type_of_user]
      }

      temp_user = User.new(sign_up_params)
      if temp_user.save
        sign_in temp_user, :bypass => true
        @organizer.user = temp_user
      else
        puts temp_user.errors.inspect
        flash[:errors] = temp_user.errors
        redirect_to organizer_welcome_path, notice: I18n.t('organizer-create-issue-message')
        return
      end
    end

    respond_to do |format|
      if @organizer.save
        sign_in_mailchimp sign_up_params[:email]
        format.html {
          if @organizer.mail_notification
            ContactMailer.notify("Uma nova conta de guia foi criada").deliver_now
            OrganizerMailer.notify(@organizer, "activate").deliver_now
          end
          redirect_to organizer_path(@organizer), notice: I18n.t('organizer-create-success')

        }
        format.json { render :show, status: :created, location: @organizer }

      else
        format.html {
          flash[:errors] = @organizer.errors
          puts @organizer.errors.inspect
          redirect_to organizer_welcome_path, notice: I18n.t('organizer-create-issue-message')
        }
        format.json { render json: @organizer.errors, status: :unprocessable_entity }
      end
    end
  end

  def create_from_auth
    if session[:organizer_welcome]
      session[:organizer_user_id] = current_user.id

      @organizer = Organizer.find(session[:organizer_id])


      if @organizer.update_attributes(user_id: session[:organizer_user_id])
        redirect_to organizer_path(@organizer), notice: I18n.t('organizer-create-success')
      else
        flash[:errors] = @organizer.errors
        puts 'errors from organizer'
        puts @organizer.errors
        redirect_to organizer_welcome_path, notice: I18n.t('organizer-create-issue-message')
      end
    else
      redirect_to organizer_welcome_path, notice: I18n.t('organizer-create-issue-message')
    end
  end


  # PATCH/PUT /organizers/1
  # PATCH/PUT /organizers/1.json
  def update
    respond_to do |format|
      if @organizer.update(organizer_params)
        format.html {
          #OrganizerMailer.notify(@organizer, "update").deliver_now
          redirect_to :back, notice: I18n.t('organizer-update-sucessfully')
        }
        format.json { render :show, status: :ok, location: @organizer }
      else
        format.html {
          flash[:errors] = @organizer.errors
          redirect_to :back, notice: I18n.t('organizer-update-error')
        }
        format.json { render json: @organizer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /organizers/1
  # DELETE /organizers/1.json
  def destroy
    @organizer.destroy
    respond_to do |format|
      format.html { redirect_to organizers_url, notice: 'Organizer was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def dashboard
    @organizer = Organizer.find(params[:id])
    @tours = @organizer.tours.order('created_at DESC')
    if params[:tour].nil?
      @tour = @organizer.tours.order('created_at DESC').first
    else
      @tour = Tour.find(params[:tour])
    end
  end

  def manage
    @organizer = Organizer.find(params[:id])
    @tours = @organizer.tours.order('created_at DESC')
    if params[:tour].nil?
      @tour = @organizer.tours.order('created_at DESC').first
    else
      @tour = Tour.find(params[:tour])
    end
  end

  def schedule
    @organizer = Organizer.find(params[:id])
  end

  def clients
    @organizer = Organizer.find(params[:id])
  end

  def account
    if @organizer.try(:marketplace)
      @missing_info = @organizer.marketplace.account_missing
    else
      @missing_info = {
          marketplace: t("no-marketplace")
      }
    end
  end

  def account_edit
    if @organizer.try(:marketplace)
      @marketplace = @organizer.marketplace
    else
      @marketplace = Marketplace.new
    end
  end

  def bank_account_edit
    @marketplace = @organizer.marketplace
    @bank_account = BankAccount.new
  end

  def account_status
    if @organizer.try(:marketplace)
      @account_missing = @organizer.marketplace.account_needed
    else
      @account_missing = [
          {
              name: "marketplace",
              label: t("marketplace-missing"),
              message: t('no-marketplace-label')
          }
      ]
    end

  end

  def import_events
    events = params["events"]
    @token = params["facebook_token"]
    @user_id = params["facebook_user_id"]

    if !events.nil?
      @response = []
      events.each do |e|
        @response.push JSON.load RestClient.get("https://graph.facebook.com/v2.9/#{e}", :content_type => :json, :accept => :json, :authorization => "OAuth #{@token}")
      end

      @response.each do |r|

        puts r.inspect

        @photo = JSON.load RestClient.get("https://graph.facebook.com/v2.9/#{r["id"]}/?fields=cover", :content_type => :json, :accept => :json, :authorization => "OAuth #{@token}")

        begin
          @tour = Tour.new({
            title: r["name"],
            start: r["start_time"],
            end: r["end_time"] || r["start_time"],
            description: r["description"],
            organizer: @organizer,
            wheres: [Where.new({:name => r["place"]["name"], :lat => r["place"]["location"]["latitude"], :long => r["place"]["location"]["longitude"]})],
            value: 20,
            photo: @photo["cover"]["source"],
            link: "http://www.facebook.com/events/#{r["id"]}",
            user: @organizer.user
          })
          if @tour.save
            flash[:success] = I18n.t('import-event-notice-success')
            redirect_to "/organizers/#{@organizer.to_param}/edit_guided_tour/#{@tour.to_param}"
          else
            puts "not saved"
            puts @tour.errors.inspect
            flash[:error] = I18n.t('import-event-notice-error')
            redirect_to "/organizers/#{@organizer.to_param}/guided_tour"
          end
        rescue => e
          flash[:error] = I18n.t('import-event-notice-error')
          redirect_to "/organizers/#{@organizer.to_param}/guided_tour"
        end
      end
    else
      flash[:error] = I18n.t('import-event-notice-error')
      redirect_to "/organizers/#{@organizer.to_param}/guided_tour", notice: I18n.t('import-event-notice')
      return
    end
  end

  def external_events
    @source = params[:source]
    @token = params[:token]
    @user_id = params[:user_id]
    if @token && @user_id
      @response = RestClient.get("https://graph.facebook.com/v2.9/#{@user_id}/events?type=created&limit=5", :content_type => :json, :accept => :json, :authorization => "OAuth #{@token}")
      @response_json = JSON.load @response
    else
      render :status => 404
    end
    #puts @response_json.inspect
    #https://www.facebook.com/v2.9/dialog/oauth?response_type=token&display=popup&client_id=1696671210617842&redirect_uri=https%3A%2F%2Fdevelopers.facebook.com%2Ftools%2Fexplorer%2Fcallback%3Fmethod%3DGET%26path%3D10154033067028556%252Fevents%253Ftype%253Dcreated%2526limit%253D2%26version%3Dv2.9&scope=rsvp_event%2Cuser_events
  end

  def confirm_account
    @organizer = Organizer.find(params[:id])
    @marketplace = @organizer.marketplace
  end

  def tos_acceptance
    @organizer = Organizer.find(params[:id])
  end

  def tos_acceptance_confirm
    @organizer = Organizer.find(params[:id])
    if Rails.env.development?
      @ip = "127.0.0.1"
    else
      @ip = params[:ip]
    end

    if request.post?
      begin
        valid_ip = IPAddr.new(@ip)
      rescue
        @status = "danger"
        @status_message = e.message
      end

     if valid_ip
        if @organizer.try(:marketplace)
          begin
            accepted = @organizer.marketplace.accept_terms(@ip)
          rescue => e
            @status = "danger"
            puts e.inspect
            @status_message = "Erro ao requisitar o stripe"
          end
          if accepted
            @status = "success"
            @status_message = "Seus termos foram aceitos com sucesso"
          else
            @status = "danger"
            @status_message = "Não conseguimos validar seus termos com o Stripe"
          end
        else
          @status = "danger"
          @status_message = "Você ainda não está cadastrado no Marketplace de guias"
        end
     else
        @status = "danger"
        @status_message = "Não foi possível aceitar seus termos. Não conseguimos obter seu IP para identificá-lo"
     end
   else
    @status = "danger"
    @status_message = "Não foi possível aceitar seus termos"
   end

  end

  def transfer
    @organizer = Organizer.find(params[:id])
    @bank_account = []
    if @organizer.try(:marketplace)
      @balance = @organizer.marketplace.balance
      @transfers = @organizer.marketplace.transfers
      @bank_account.push(@organizer.marketplace.bank_account_active)
    else
      @transfers = []
      @balance = {}
    end
  end

  #deprecated - convert to stripe manual transfer (the money is transfered automatically)
  def transfer_funds
    @organizer = Organizer.find(params[:id])
    @amount = raw_price(params[:amount])
    @current = raw_price(params[:current])

    if params[:amount].nil?
      @status = "danger"
      @message_status = "Você não especificou um valor"
      return
    end

    @bank_account_active_id = @organizer.marketplace.bank_account_active.own_id
    if @bank_account_active_id.nil?
      @status = "danger"
      @message_status = "Você não tem nenhuma conta bancária ativa no momento"
    else
      if @amount <= @current
         bank_transfer_data = {
              "amount" => @amount,
              "transferInstrument" => {
                  "method" => "BANK_ACCOUNT",
                  "bankAccount" => {
                      "id" => @bank_account_active_id,
                  }
              }
          }
          response_transfer = RestClient.post("#{Rails.application.secrets[:moip_domain]}/transfers", bank_transfer_data.to_json, :content_type => :json, :accept => :json, :authorization => "OAuth #{@organizer.marketplace.token}"){|response, request, result, &block|
              case response.code
                when 401
                  @status = "danger"
                  @message_status = "Você não está autorizado a realizar esta transação"
                  @response_transfer_json = JSON.load response
                when 400
                  @status = "danger"
                  @message_status = "Não foi possíel realizar a transferência"
                  @response_transfer_json = JSON.load response
                when 200
                  @status = "danger"
                  @message_status = "Não foi possível realizar a transferência"
                  @response_transfer_json = JSON.load response
                when 201
                  @status = "success"
                  @message_status = "Solicitação de transferência realizada com sucesso"
                  @response_transfer_json = JSON.load response
                  MarketplaceMailer.transfer(@organizer, friendly_price(@response_transfer_json["amount"]), l(@response_transfer_json["updatedAt"].to_datetime, format: '%d de %B de %Y as %Hh%M')).deliver_now
                else
                  @activation_message = "Não conseguimos resposta do MOIP para a transferência soliticata, verifique os dados novamente."
                  @activation_status = "danger"
                  @response_transfer_json = JSON.load response
                end
          }
      else
         @status = "danger"
         @message_status = "Você não tem fundos suficientes para realizar esta transferência"
      end
    end

  end

  def marketplace

  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_organizer
      @organizer = Organizer.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def organizer_params
      #params.fetch(:organizer, {}).permit(:welcome, :policy, :name, :marketplace_id, :description, :picture, :user_id, :percent, :members, {:members_attributes => []}, {:wheres_attributes => [:id, :name, :lat, :long, :city, :state, :country, :postal_code, :address, :url, :google_id, :place_id]}, :email, :website, :facebook, :twitter, :instagram, :phone, :status).merge(params[:organizer])
      params.fetch(:organizer, {}).permit!
    end

    def sign_in_mailchimp email
      begin
        gibbon = Gibbon::Request.new(api_key: ENV['MAILCHIMP_KEY'],
                                     symbolize_keys: true)
        gibbon.timeout = 10
        gibbon.lists(ENV['MAILCHIMP_LIST_ID']).members
              .create(body: { email_address: email,
                              status: 'subscribed' })
      rescue Gibbon::MailChimpError => e
        puts "Email já cadastrado ou inválido: #{email}"
      end
    end

end
