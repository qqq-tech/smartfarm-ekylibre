# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2014 Brice Texier, David Joulin
# Copyright (C) 2015-2023 Ekylibre SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: intervention_parameters
#
#  allowed_entry_factor     :interval
#  allowed_harvest_factor   :interval
#  applications_frequency   :interval
#  assembly_id              :integer(4)
#  batch_number             :string
#  component_id             :integer(4)
#  created_at               :datetime         not null
#  creator_id               :integer(4)
#  currency                 :string
#  dead                     :boolean          default(FALSE), not null
#  event_participation_id   :integer(4)
#  group_id                 :integer(4)
#  id                       :integer(4)       not null, primary key
#  identification_number    :string
#  imputation_ratio         :decimal(19, 4)   default(1), not null
#  intervention_id          :integer(4)       not null
#  lock_version             :integer(4)       default(0), not null
#  new_container_id         :integer(4)
#  new_group_id             :integer(4)
#  new_name                 :string
#  new_variant_id           :integer(4)
#  outcoming_product_id     :integer(4)
#  position                 :integer(4)       not null
#  product_id               :integer(4)
#  quantity_handler         :string
#  quantity_indicator_name  :string
#  quantity_population      :decimal(19, 4)
#  quantity_unit_name       :string
#  quantity_value           :decimal(19, 4)
#  reference_data           :jsonb            default("{}")
#  reference_name           :string           not null
#  specie_variety           :jsonb            default("{}")
#  spray_volume_value       :decimal(19, 4)
#  type                     :string
#  unit_pretax_stock_amount :decimal(19, 4)   default(0.0), not null
#  updated_at               :datetime         not null
#  updater_id               :integer(4)
#  usage_id                 :string
#  using_live_data          :boolean          default(TRUE)
#  variant_id               :integer(4)
#  working_zone             :geometry({:srid=>4326, :type=>"multi_polygon"})
#  working_zone_area_value  :decimal(19, 4)
#
require 'test_helper'

class InterventionProductParameterTest < Ekylibre::Testing::ApplicationTestCase::WithFixtures
  test_model_actions

  test '#nullify_working_zone_if_working_zone_area before_validation callback' do
    target = create(:intervention_target, :with_working_zone)
    target.update(working_zone_area: 10)
    assert_nil(target.reload.working_zone)
  end

  test '#set_working_zone_area_from_working_zone before_validation callback' do
    target = build(:intervention_target, :with_working_zone)
    area = target.working_zone.area
    target.send(:set_working_zone_area_from_working_zone)
    assert(Measure.new(area.round(4), 'square_meter').in_hectare.round(4).inspect == target.working_zone_area.inspect )
  end

  test '#set_quantity_from_working_zone before_validation callback' do
    target = build(:intervention_target, :with_working_zone)
    area = target.working_zone.area
    target.send(:set_quantity_from_working_zone)
    assert(Measure.new(area.round(4), 'square_meter').inspect == target.quantity.inspect )
  end

  test '#handle_product_dead_at after_save callback' do
    target = create(:intervention_target, :with_working_zone, dead: false)
    assert_not_nil(target.product.dead_at, 'If it doesn\'t destroy, the product dead_at should not change')

    target = create(:intervention_target, :with_working_zone, dead: true)
    stopped_at = target.stopped_at
    product = target.product
    assert_equal(stopped_at, target.product.dead_at, 'If it destroy, the product dead_at should be equal to intervention stopped_at, only if it\'s anterior to product dead_at')

    target.update(dead: false)
    assert_equal(product.initial_dead_at, target.product.dead_at, "If it changes form dead to alive, the product dead_at should be equal to initial dead_at")
  end
end
