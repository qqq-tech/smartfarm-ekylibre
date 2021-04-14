# frozen_string_literal: true

module Interventions
  module Phytosanitary
    class PfiClientApi
      attr_reader :campaign, :activity, :intervention_parameter_input, :area_ratio, :activities

      # https://alim.agriculture.gouv.fr/ift-api/swagger-ui.html
      BASE_URL = "https://alim.agriculture.gouv.fr/ift-api"
      PFI_CAMPAIGN_URL = "/api/campagnes"
      PFI_COMPUTE_URL = "/api/ift/traitement"
      PFI_COMPUTE_SIGN_URL = "/api/ift/traitement/certifie"
      PFI_REPORT_PDF_URL = "/api/ift/bilan/pdf"

      # transcode unit
      TRANSCODE_UNIT = {
                        kilogram_per_hectare: "U1", # KG/HA
                        kilogram_per_hectoliter: "U2", # KG/HL
                        liter_per_hectare: "U3", # L/HA
                        liter_per_hectoliter: "U4", # L/HL
                        unit_per_hectare: "U5", # Unité/HA
                        unit_per_hectoliter: "U8" # Unité/HL
                        }.freeze

      # @param [Campaign] campaign
      # @param [Activity] activity
      # @param [InterventionInput] intervention_parameter_input
      # @param [Decimal] area_ratio
      def initialize(campaign:, activity: nil, intervention_parameter_input: nil, area_ratio: 100, activities: nil, report_title: nil)
        @campaign = campaign
        @activity = activity
        @intervention_parameter_input = intervention_parameter_input
        @area_ratio = area_ratio
        # for pdf pfi report only
        @activities = activities
        @report_title = report_title || @campaign.name
      end

      # Compute pfi for one input on intervention
      def compute_pfi(with_signature: true)
        return nil if @activity.nil? || @intervention_parameter_input.nil?

        # check if campaign is available on api
        begin
          campaign_url = BASE_URL + PFI_CAMPAIGN_URL + "/#{@campaign.harvest_year}"
          RestClient.get campaign_url
        rescue RestClient::ExceptionWithResponse => e
          e.response
          return nil
        end

        # build url if we want signature
        if with_signature == true
          url = BASE_URL + PFI_COMPUTE_SIGN_URL
        else
          url = BASE_URL + PFI_COMPUTE_URL
        end

        # build params and return nil if no mandatory params is set
        p = build_params(@intervention_parameter_input)
        if p
          # call API and get response
          call = RestClient::Request.execute(method: :get, url: url, headers: { params: p })
          response = JSON.parse(call.body).deep_symbolize_keys
        else
          nil
        end
      end

      # Compute pfi report for all input on all interventions in each activity production of a campaign
      def compute_pfi_report
        return nil if @activities.nil?

        url = BASE_URL + PFI_REPORT_PDF_URL
        params = "?campagneIdMetier=#{grab_harvest_year}&titre=#{@report_title}"
        url << params
        # params["parcellesCultivees"] = build_crops
        body = build_crops
        # call API and get response
        begin
          response = RestClient.post url, body.to_json, content_type: 'application/json'
          { status: true, body: response.body }
          # RestClient::Request.execute(method: :post, url: url, payload: body, headers: params)
        rescue RestClient::ExceptionWithResponse => err
          { status: false, body: err.response }
        end
      end

      private

        def build_params(intervention_input)
          params = {}
          # mandatory params for API
          params["campagneIdMetier"] = grab_harvest_year
          params["cultureIdMetier"] = grab_pfi_crop_code(@activity)
          params["typeTraitementIdMetier"] = grab_pfi_treatment_nature(intervention_input)

          # check mandatory params is present
          params.each do |_k, v|
            if v.nil? || v.blank?
              return nil
              # raise StandardError.new(:missing_mandatory_attribute, attribute: k, value: v)
            end
          end

          normalized_unit = grab_normalized_quantity(intervention_input)
          if normalized_unit
            # not mandatory for API
            params["numeroAmmIdMetier"] = grab_france_maaid_from_usage(intervention_input) if grab_france_maaid_from_usage(intervention_input)
            params["uniteIdMetier"] = TRANSCODE_UNIT[normalized_unit.unit.to_sym] if normalized_unit
            params["dose"] = normalized_unit.value.to_f if normalized_unit
            params["facteurDeCorrection"] = @area_ratio
            params["cibleIdMetier"] = grab_pfi_target_nature(intervention_input) if grab_pfi_target_nature(intervention_input)
            params["volumeDeBouillie"] = ""
            params["produitLibelle"] = intervention_input.product.name
          end
          params
        end

        def build_crops
          # compute crop
          crops = {}.with_indifferent_access
          crops["parcellesCultivees"] = []
          @activities.each do |activity|
            ActivityProduction.where(activity_id: activity.id, campaign_id: @campaign.id).each do |ap|
              crop = {}.with_indifferent_access
              crop["type"] = 'parcelle'
              crop["campagne"] = { idMetier: @campaign.harvest_year, libelle: @campaign.name, active: true }
              crop["culture"] = { idMetier: grab_pfi_crop_code(activity), libelle: "", groupeCultures: { idMetier: "", libelle: "" } }
              crop["parcelle"] = { nom: ap.name, surface: ap.support_shape_area.convert(:hectare).to_f.round(2) }
              crop["traitements"] = []
              ap.interventions.of_nature_using_phytosanitary.each do |int|
                int.inputs.each do |intervention_input|
                  treatment = compute_crop_interventions_for_pfi_report(ap, intervention_input)
                  crop["traitements"] << treatment if treatment
                end
              end
              crops["parcellesCultivees"] << crop
            end
          end
          crops
        end

        def compute_crop_interventions_for_pfi_report(ap, intervention_input)
          product_ids = Product.where(activity_production_id: ap.id).pluck(:id)
          target_ids = InterventionTarget.where(product_id: product_ids).pluck(:id)
          pfi_data = PfiInterventionParameter.find_by(nature: 'crop', input_id: intervention_input.id, target_id: target_ids)
          if pfi_data.present?
            traitement = pfi_data.response["iftTraitement"]
            traitement["id"] = pfi_data.response["id"]
            traitement["date"] = intervention_input.intervention.started_at.strftime("%FT%T.%LZ")
            traitement["dateTraitement"] = intervention_input.intervention.started_at.strftime("%Y-%m-%d")
            traitement
          else
            nil
          end
        end

        def grab_harvest_year
          @campaign.harvest_year || nil
        end

        def grab_pfi_crop_code(activity)
          if activity.production_nature
            activity.production_nature.pfi_crop_code
          else
            nil
          end
        end

        def grab_pfi_treatment_nature(intervention_input)
          if intervention_input&.usage&.target_name_label_fra
            pfi_target = intervention_input.usage.pfi_target
            pfi_target.default_pfi_treatment_type_id if pfi_target
          else
            nil
          end
        end

        def grab_pfi_target_nature(intervention_input)
          if intervention_input&.usage&.target_name_label_fra
            pfi_target = intervention_input.usage.pfi_target
            if pfi_target && pfi_target.pfi_id.present?
              pfi_target.pfi_id
            else
              nil
            end
          else
            nil
          end
        end

        def grab_france_maaid_from_usage(intervention_input)
          if intervention_input&.usage&.france_maaid
            intervention_input.usage.france_maaid
          else
            nil
          end
        end

        # return Measure for mass or volume_area_density
        def grab_normalized_quantity(intervention_input)
          quantity_area = intervention_input&.input_quantity_per_area
          if quantity_area
            case quantity_area.dimension
            when :volume_area_density then quantity_area.convert(:liter_per_hectare)
            when :mass_area_density then quantity_area.convert(:kilogram_per_hectare)
            else nil
            end
          else
            nil
          end
        end

    end
  end
end
