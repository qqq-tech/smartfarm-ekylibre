require 'test_helper'
module Api
  module V1
    class CrumbsControllerTest < Ekylibre::Testing::ApplicationControllerTestCase::WithFixtures
      connect_with_token

      test 'create' do
        post :create, params: { nature: 'point', geolocation: 'SRID=4326;POINT(0 0)', read_at: Time.zone.now.iso8601, accuracy: 10, device_uid: 'android-123' }
        json = JSON.parse response.body
        assert_response :created, json.to_yaml
      end

      test 'create with other data' do
        post :create, params: { nature: 'point', geolocation: 'SRID=4326;POINT(1 1)', read_at: Time.zone.now.iso8601, accuracy: 10, device_uid: 'android-123', format: 'json', foo: 'bar' }
        json = JSON.parse response.body
        assert_response :created, json.to_yaml
      end
    end
  end
end
