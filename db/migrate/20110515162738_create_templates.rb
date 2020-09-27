class CreateTemplates < ActiveRecord::Migration
  def self.up
    create_table :templates do |t|
      t.text :all_resources
      t.text :all_errors
      t.text :selected_resources

      t.timestamps
    end
  end

  def self.down
    drop_table :templates
  end
end
