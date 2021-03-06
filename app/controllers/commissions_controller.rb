class CommissionsController < ApplicationController
  before_filter :verify_logged_in
  def show
    @commission = Commission.find(params[:commission_id])
  end

  def review
    @commission = Commission.find(params[:commission_id])
    @artist = User.find(@commission.artist_id)
    @json = @commission.commission_current
    if @commission.state == "Complete"
      @image = Image.find(@commission.commission_current["image"])
      if @image.nil?
        flash[:alert] = "Image missing!"
      end
    end
  end

  def requests
    @user = current_user
  end

  def edit
    @artist = User.find(params[:artist_id])
    @json = User.find(params[:artist_id]).commission_request_template_json
  end

  def create
    @template = User.find(params[:artist_id]).commission_request_template_json
    @user = current_user
    json = build_json_from_params
    @commission = Commission.new do |t|
      t.state = "NewRequest"
      t.artist_id = params[:artist_id]
      t.commissioner_id = @user.id
      t.commission_current = json
    end
    if @commission.save
      flash[:notice] = "Commission successfully sent!"
      redirect_to root_url
    else
      for message in @commission.errors.full_messages do
        if i == 0
          flash[:alert] = message
          i = 1
        else
          flash[:alert] << ", " + message
        end
      end
    end
  end

  def accept
    @commission = Commission.find(params[:commission_id])

    if current_user != nil && current_user.id == @commission.artist_id
      @commission.state = "Accepted"
      @commission.save
      flash[:notice] = "Commission Accepted!"
      redirect_to commissions_requests_path
    end
  end
  
  def catch_post_review
    switch = params[:post]
    if switch == "Decline"
      decline
    elsif switch == "Submit Revision"
      revision
    end
  end

  def revision
    @commission = Commission.find(params[:commission_id])
    @commission.state = "Review"
    @json = @commission.commission_current
    if current_user.id == @commission.commissioner_id
      @json["spec"] << params[:revision]
    else
      if @json["review"].nil?
        @json["review"] = [params[:review]]
      else
        @json["review"] << params[:review]
      end 
      if params["price"] != ""
        @json["price"] = params[:price]
      end
    end
    @commission.commission_current = nil
    @commission.save
    @commission.commission_current = @json
    @commission.save
    flash[:notice] = "Commission revision updated!"
    redirect_to commissions_requests_path
  end

  def decline
    @commission = Commission.find(params[:commission_id])
    if current_user != nil && current_user.id == @commission.artist_id
      @commission.state = "Declined"
      @json = @commission.commission_current
      @json["decline"] = params[:post]
      @commission.commission_current = nil
      @commission.save
      @commission.commission_current = @json
      @commission.save
      flash[:notice] = "Commission Declined!"
      redirect_to commissions_requests_path
    end
  end

  def progress
    @commission = Commission.find(params[:commission_id])
    @artist = User.find(@commission.artist_id)
    @json = @commission.commission_current
  end

  def complete
    @commission = Commission.find(params[:commission_id])
    @json = @commission.commission_current
    @image = Image.new do |t|
      t.data = params["picture"].read
      t.filename = params["picture"].original_filename
      t.file_type = params["picture"].content_type
      t.artist_id = @commission.artist_id
    end
    if @image.save
      @json["image"] = @image.id
      @commission.commission_current = nil
      @commission.save
      @commission.commission_current = @json
      @commission.state = "Complete"
      @commission.save
      flash[:notice] = "Commission Completed!"
    end
    redirect_to review_path(params[:commission_id])
  end

  def finish
    @commission = Commission.find(params[:commission_id])
    @commission.state = "In Progress"
    if @commission.save
    else
      i = 0
      for message in @commission.errors.full_messages do
        if i == 0
          flash[:alert] = message
          i = 1
        else
          flash[:alert] << ", " + message
        end
      end
    end
    flash[:notice] = "Commission Finalized!"
    redirect_to commissions_requests_path
  end

private
  def testing
    flash[:alert] = @template["categories"][0]["steps"]
  end

  def build_json_from_params
    blob = {}
    i = 0
    category_blob = {}
    price = 0
    params.each do |k, v|
      if k.starts_with? "option"
        if i == 0
          category = category_number(k)
          category_blob = @template["categories"][category]
          blob["name"] = "Commission from " + current_user.name + " for " +
            category_blob["name"]
          blob["steps"] = []
          i = 1
        end
        blob_step = {}
        num = step_number(k)
        choice_num = v.to_i
        blob_step["name"] = category_blob["steps"][num]["name"]
        blob_step["choice"] = category_blob["steps"][num]["options"][choice_num]
        price += blob_step["choice"]["price"].to_i
        blob["steps"] << blob_step      
      elsif k.starts_with? "final"
        blob["spec"] = [v];
      end
    end
    blob["price"] = price
    blob["review"] = []
    return blob
  end

  def category_number(string)
    return string.split('-',5)[1].to_i
  end

  def step_number(string)
    return string.split('-',5)[2].to_i
  end
end
