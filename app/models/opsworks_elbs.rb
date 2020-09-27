class OPSWORKS_Elbs < CF_converter
  
  attr_accessor :name
  @@resource_id = 1
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Opsworks Layers
      opsworks = AWS::OpsWorks.new()
      elbs = []
      all_resources[:opsworks_stacks].each do |stack|
        opsworks.client.describe_elastic_load_balancers({:stack_id => stack[:stack_id]}).data[:elastic_load_balancers].each do |elb|
          elb[:name] = "elbattach#{elb[:elastic_load_balancer_name]}#{@@resource_id}"
          @@resource_id = @@resource_id + 1
          elb[:stack_name] = stack[:name]
          all_resources[:opsworks_layers].each do |layer|
            elb[:layer_name] = layer[:name] if layer[:layer_id].eql?(elb[:layer_id])
          end if all_resources[:opsworks_layers]
          elbs << elb
        end
      end if all_resources[:opsworks_stacks]
      all_resources.merge!({:opsworks_elbs => elbs})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:opsworks_elbs => "Not supported in this region"})
      else
        all_errors.merge!({:opsworks_elbs => e.message})
      end
      all_resources.merge!({:opsworks_elbs => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Stack Name: #{resource[:stack_name]}\n" +
           "Layer Name: #{resource[:layer_name]}\n" +
           "Load Balancer: #{resource[:elastic_load_balancer_name]}"
  end

  def self.get_dependencies(resource, all_resources)
    elbs = []
    all_resources[:elbs].each do |elb|
      elbs.push(elb) if elb[:load_balancer_name].eql?(resource[:elastic_load_balancer_name])
    end if all_resources[:elbs]
    return { :elbs => elbs }
  end

  def initialize(resource)
    @name = OPSWORKS_Elbs.ResourceName(resource)
    super(@name, "AWS::OpsWorks::ElasticLoadBalancerAttachment")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"ElasticLoadBalancerName" => ref_or_literal(:elbs, resource[:elastic_load_balancer_name], template, name_mappings)})
    props.merge!({"LayerId" => ref_or_literal(:opsworks_layers, resource[:layer_name], template, name_mappings)})

    return @cf_definition.deep_merge({ OPSWORKS_Elbs.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})

  end
end
