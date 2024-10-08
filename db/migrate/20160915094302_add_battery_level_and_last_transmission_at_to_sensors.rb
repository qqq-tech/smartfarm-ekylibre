class AddBatteryLevelAndLastTransmissionAtToSensors < ActiveRecord::Migration[4.2]
  def change
    add_column :sensors, :battery_level, :decimal, precision: 19, scale: 4
    add_column :sensors, :last_transmission_at, :datetime
  end
end
