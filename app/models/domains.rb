class Domains < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the SDB domains we care about
      sdb = AWS::SimpleDB.new(:region => region)
      sdb_domains = []
      sdb.domains.each do |domain|
        sdb_domains << {:name => domain.name}
      end
      all_resources.merge!({:domains => sdb_domains})
    rescue => e
      if region.eql?("us-gov-west-1") || region.eql?("eu-central-1") || region.eql?("cn-north-1") || region.eql?("ap-northeast-2") || region.eql?("cn-northwest-1")
        all_errors.merge!({:domains => "Not supported in this region"})
      else
        all_errors.merge!({:domains => e.message})
      end
      all_resources.merge!({:domains => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "sdb" + resource[:name].tr('^A-Za-z0-9', '') 
  end

  def self.OutputList(resource)
    return {"Domain Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Domains.ResourceName(resource)
    super(@name, "AWS::SDB::Domain")
  end
  
  def convert(resource, template, name_mappings)
    return @cf_definition.deep_merge({ Domains.map_resource_name(@name, name_mappings) => { "Type" => @cf_type }})
  end
    
end
