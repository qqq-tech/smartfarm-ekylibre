# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2015 Brice Texier, David Joulin
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
# == Table: production_distributions
#
#  affectation_percentage :decimal(19, 4)   not null
#  created_at             :datetime         not null
#  creator_id             :integer
#  id                     :integer          not null, primary key
#  lock_version           :integer          default(0), not null
#  main_production_id     :integer          not null
#  production_id          :integer          not null
#  updated_at             :datetime         not null
#  updater_id             :integer
#
class ProductionDistribution < Ekylibre::Record::Base
  belongs_to :production, inverse_of: :distributions
  belongs_to :main_production, class_name: "Production"
  has_one :activity, through: :production
  has_one :main_activity, through: :main_production
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_numericality_of :affectation_percentage, allow_nil: true
  validates_presence_of :affectation_percentage, :main_production, :production
  #]VALIDATORS]
  validates_numericality_of :affectation_percentage, greater_than: 0

  delegate :name, to: :main_production, prefix: true
end
