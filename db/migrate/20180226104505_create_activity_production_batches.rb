class CreateActivityProductionBatches < ActiveRecord::Migration[4.2]
  def change
    unless data_source_exists?(:activity_production_batches)
      create_table :activity_production_batches do |t|
        t.integer :number
        t.integer :day_interval
        t.boolean :irregular_batch, default: false
        t.references :activity_production, index: { name: :activity_production_batch_id }, foreign_key: true
        t.timestamps null: false
      end
    end
  end
end
