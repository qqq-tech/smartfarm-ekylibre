# -*- coding: utf-8 -*-
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class Backend::ListingsController < BackendController

  unroll

  list(:order => :name) do |t|
    t.column :name, url: {:action => :edit}
    t.column :root_model_name
    t.column :description
    t.action :extract, url: {:format => :csv}, image: :action
    # t.action :extract, url: {:format => :csv, :mode => :no_mail}, :if => :can_mail?, image: :nomail
    t.action :mail, :if => :can_mail?
    t.action :duplicate, :method => :post
    t.action :edit
    t.action :destroy
  end

  # Displays the main page with the list of listings
  def index
    session[:listing_coordinate_column] = nil
  end

  def extract
    return unless @listing = find_and_check(:listing)
    begin
      @listing.save if @listing.query.blank?
      query = @listing.query.to_s
      # FIXME: This is dirty code to solve quickly no_mail mode
      query.gsub!(" ORDER BY ", " AND (" + @listing.coordinate_columns.collect{|c| "#{c.name} NOT LIKE '%@%.%'" }.join(" AND ") + ") ORDER BY ") if params[:mode] == "no_mail"
      # FIXME: Manage suppression of CURRENT_COMPANY...
      first_item = []
      @listing.exportable_columns.each {|item| first_item << item.label}
      result = ActiveRecord::Base.connection.select_rows(query)
      result.insert(0, first_item)

      respond_to do |format|
        format.xml { render :xml => result.to_xml, :filename => @listing.name.simpleize+'.xml' }
        format.csv do
          csv_string = Ekylibre::CSV.generate do |csv|
            for item in result
              csv << item
            end
          end
          send_data(csv_string, :filename => @listing.name.simpleize+'.csv', :type => Mime::CSV)
        end
      end

    rescue Exception => e
      notify_error(:fails_to_extract_listing, :message => e.message)
      redirect_to_current
    end
  end

  def new
    @listing = Listing.new
    # render_restfully_form
  end

  def create
    @listing = Listing.new listing_params
    return if save_and_redirect(@listing, url: {:action => :edit, :id => "id"})
    # render_restfully_form
  end

  def edit
    return unless @listing = find_and_check(:listing)
    t3e @listing.attributes
    # render_restfully_form
  end

  def update
    return unless @listing = find_and_check(:listing)
    @listing.attributes = listing_params
    return if save_and_redirect(@listing, url: {:action => :edit, :id => "id"})
    t3e @listing.attributes
    # render_restfully_form
  end

  def destroy
    return unless @listing = find_and_check(:listing)
    if request.post? or request.delete?
      Listing.destroy(@listing.id) if @listing
    end
    redirect_to :action => :index
  end

  def duplicate
    return unless @listing = find_and_check(:listing)
    @listing.duplicate if request.post?
    redirect_to :action => :index
  end

  def mail
    return unless @listing = find_and_check(:listing)
    if (query = @listing.query).blank?
      @listing.save
      query = @listing.query
    end
    query = query.to_s
    if !@listing.can_mail? or query.blank?
      notify_warning(:you_must_have_an_email_column)
      redirect_to_back
      return
    end
    if session[:listing_coordinate_column] or @listing.coordinate_columns.count == 1
      full_results = ActiveRecord::Base.connection.select_all(query)
      listing_coordinate_column = @listing.coordinate_columns.count == 1 ? @listing.coordinate_columns[0] : find_and_check(:listing_nodes, session[:listing_coordinate_column])
      #raise Exception.new listing_coordinate_column.inspect
      results = full_results.select{|c| !c[listing_coordinate_column.label].blank? }
      @mails = results.collect{|c| c[listing_coordinate_column.label] }
      # @mails.uniq! ### CHECK ????????
      @columns = (full_results.size > 0 ? full_results[0].keys.sort : [])
      session[:mail] ||= {}
    end
    if request.post?
      if params[:node]
        session[:listing_coordinate_column] = ListingNode.find_by_key(params[:node][:mail]).id
        redirect_to_current
      else
        session[:mail] = params.dup
        session[:mail].delete(:attachment)
        texts = [params[:mail_subject], params[:mail_body]]
        if attachment = (params[:attachment].blank? ? nil : params[:attachment])
          # file = "#{Rails.root.to_s}/tmp/uploads/attachment_#{attachment.original_filename.gsub(/\W/,'_')}"
          # File.open(file, "wb") { |f| f.write(attachment.read)}
          attachment = {:filename => attachment.original_filename, :content_type => attachment.content_type, :body => attachment.read.dup}
        end
        if params[:send_test]
          results = [results[0]]
          results[0][listing_coordinate_column.label] = params[:from]
        end
        for result in results
          ts = texts.collect do |t|
            r = t.to_s.dup
            @columns.each{|c| r.gsub!(/\{\{#{c}\}\}/, result[c].to_s)}
            r
          end
          Mailman.mailing(params[:from], result[listing_coordinate_column.label], ts[0], ts[1], attachment).deliver
        end
        notify_success_now(:mails_are_sent)
	# nature = EventNature.where(:usage => "mailing").first
        # nature = EventNature.create!(:name => tc(:mailing), :duration => 5, :usage => "mailing") if nature.nil?
        # #raise Exception.new nature.inspect
	# EntityAddress.emails.where(:coordinate => @mails).find_each do |address|
        #   Event.create!(:entity_id => address.entity_id, :started_at => Time.now, :duration => 5, :nature_id => nature.id, :user_id => @current_user.id)
        # end
        session[:listing_coordinate_column] = nil
      end
    end
    t3e @listing.attributes
  end

  protected

  def listing_params()
    params.require(:listing).permit!
  end

end
