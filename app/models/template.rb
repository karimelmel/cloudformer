class Template < ActiveRecord::Base
  
  serialize :all_resources
  serialize :all_errors
  serialize :selected_resources

  attr_writer :current_step
  
  def current_step
    @current_step || steps.first
  end
  
  def steps
    %w[info dns vpc vpc_network vpc_security network managed_services managed_config compute storage config middleware security operations summary done]
  end
  
  def resources_for_step
    {
      "info" => [:description, :filter, :selectall],
      "dns" => [:r53_hostedzones, :r53_recordsets, :r53_healthchecks],
      "vpc" => [:vpcs],
      "vpc_network" => [:subnets, :igws, :cgws, :vgws, :dhcps, :vpn_connections, :vpc_peers],
      "vpc_security" => [:network_acls, :route_tables],
      "managed_services" => [:as_groups, :eb_applications, :opsworks_stacks],
      "managed_config" => [:launch_configs, :eb_versions, :eb_environments, :eb_templates, :opsworks_apps, :opsworks_layers, :opsworks_elbs],
      "network" => [:elbs, :eips, :enis, :distributions],
      "compute" => [:instances, :opsworks_instances],
      "storage" => [:volumes, :dbs, :caches, :redshift_clusters, :tables, :buckets, :domains],
      "config" => [:db_subnet_groups, :db_parameter_groups, :cache_subnet_groups, :cache_parameter_groups, :redshift_subnet_groups, :redshift_parameter_groups],
      "middleware" => [:queues, :topics, :streams],
      "security" => [:security_groups, :db_security_groups, :cache_security_groups, :redshift_security_groups, :queue_policies, :topic_policies, :bucket_policies],
      "operations" => [:scaling_policies, :scheduled_actions, :alarms, :trails], # :triggers
      "summary" => [:network_acl_entries, :subnet_acl_associations, :gateway_attachments, :subnet_route_associations, :route_table_entries, :dhcp_associations, :eipassociations, :eniattachments, :securitygroupingresses, :securitygroupegresses, :cachesecuritygroupingresses, :redshiftsecuritygroupingresses, :vpn_connection_routes],
      "done" => []
    }
  end
  
  def text_for_step
    {
      "info" => {
        :step_title => "Template Information",
        :step_breadcrumb => "Intro",
        :step_description => "Select the AWS region to introspect. The description is optional but will be displayed " +
                             "in the AWS Management console when the template is used to create a stack. You can optionally enter a filter for " +
                             "the resources. If you specify a filter, all resources with a name or a tag value that contains the filter text " + 
                             "will be selected automatically. Note that the filter is a case-insentive match."
      },
      "dns" => {
        :step_title => "DNS Names",
        :step_breadcrumb => "DNS",
        :step_description => "Select the DNS configuration to be included in the template." 
      },
      "vpc" => {
        :step_title => "Virtual Private Clouds",
        :step_breadcrumb => "VPC",
        :step_description => "Select the Virtual Private Clouds (VPCs) to be included in the template. " +
                             "If you select a VPC, all VPC network and security settings will be selected for inclusion " +
                             "in the template by default, however, you can customize them in the next steps." 
      },
      "vpc_network" => {
        :step_title => "Virtual Private Cloud Network Topologies",
        :step_breadcrumb => "VPC Network",
        :step_description => "Select the Virtual Private Cloud (VPC) network configuration to be included in the template." 
      },
      "vpc_security" => {
        :step_title => "Virtual Private Cloud Security Configuration",
        :step_breadcrumb => "VPC Security",
        :step_description => "Select the Virtual Private Cloud (VPC) security configuration to be included in the template." 
      },
      "managed_services" => {
        :step_title => "Managed Services",
        :step_breadcrumb => "Managed Services",
        :step_description => "Select the managed services to include in the template. You can customize the content of " +
                             "the managed services in the next steps."
      },
      "managed_config" => {
        :step_title => "Managed Service Configuration",
        :step_breadcrumb => "Managed Config",
        :step_description => "Select the configuration for managed services."
      },
      "network" => {
        :step_title => "Network Resources",
        :step_breadcrumb => "Network",
        :step_description => "Select the network entry points to be included in the template. " +
                             "If you select an EIP or and ENI that has an instance associated with it or an Elastic Load " +
                             "Balancer that has instances or an Auto Scaling group associated with it, the instances or Auto " +
                             "Scaling groups will be selected for inclusion in the template by default, however, " +
                             "you can customize them in the next step."
      },
      "compute" => {
        :step_title => "Compute Resources",
        :step_breadcrumb => "Compute",
        :step_description => "Select the EC2 instances and OpsWorks instances to be included in the template." +
                             "If you select instances that are associated with EBS volumes, the volumes will be selected " +
                             "for inclusion in the template by default, however, you can customize them in the next step."
      },
      "storage" => {
        :step_title => "Storage",
        :step_breadcrumb => "Storage",
        :step_description => "Select the EBS Volumes, RDS Database Instances, ElastiCache clusters, Redshift clusters " +
                             "DynamoDB tables, SimpleDB domains and S3 buckets to be included in the template. " +
                             "Note that the master password of any RDS database instances will be hardcoded in the template. " +
                             "You should edit the final template with appropriate values."
      },
      "security" => {
        :step_title => "Security Groups",
        :step_breadcrumb => "Security",
        :step_description => "Select the Security Groups and Policies to be included in the template. The default security " +
                             "groups in the account can be copied in case they have been modified."
      },
      "middleware" => {
        :step_title => "Application Services",
        :step_breadcrumb => "App Services",
        :step_description => "Select the SQS queues, SNS Topics and Kinesis Streams to be included in the template."
      },
      "config" => {
        :step_title => "Storage Configuration",
        :step_breadcrumb => "Storage Config",
        :step_description => "Select additional configuration for your Storage Services."
      },
      "operations" => {
        :step_title => "Operational Resources",
        :step_breadcrumb => "Operational",
        :step_description => "Select the Auto Scaling Triggers to be included in the template."
      },
      "summary" => {
        :step_title => "Summary",
        :step_breadcrumb => "Summary",
        :step_description => "You have selected the following resources. We have automatically generated logical resource names " +
                             "for the template, however, you can assign your own names by editing them if you prefer. You can also " +
                             "select any output values that you want to return when the stack is created. Output values are displayed " +
                             "in the AWS management console when you select the stack in the AWS CloudFormation tab. To edit the logical " +
                             "name or to select output parameters, click on the modify link for each resource you want to change."
      },    
      "done" => {
        :step_title => "Done",
        :step_breadcrumb => "Done",
        :step_description => "Done"
      }    
    }
  end

  def resource_metadata
    {
      :name => {
        :resource_title => "Template Name",
        :resource_type => :text,
        :resource_attributes => :single_line,
        :resource_annotation => "Name to be used as the template file name",
        :template_section => :template
      },
      :description => {
        :resource_title => "Template Description",
        :resource_type => :text,
        :resource_attributes => :multi_line,
        :resource_annotation => "Enter template description",
        :resource_tooltip => "The template description is included in the template and displayed in the " +
                              "AWS Management Console when the template is used to create a stack.",
        :template_section => :template    
      },
      :filter => {
        :resource_title => "Resource Name Filter",
        :resource_type => :text,
        :resource_attributes => :single_line,
        :resource_annotation => "Select resources matching filter",
        :template_converter => "Filter",
        :resource_tooltip => "Any AWS resource whose name contains the filter string will be automatically selected. " +
                             "This allows you to easily select a set of resources if you have already implemented a " +
                             "naming convention for your AWS resources.",
        :template_section => :none        
      },
      :selectall => {
        :resource_title => "Select all resources in your account",
        :resource_type => :option,
        :resource_attributes => :single_line,
        :template_converter => "Select_All",
        :resource_tooltip => "Select all resources in your account by default. " +
                             "You can de-select resources you don't want to include in your template.",
        :template_section => :none        
      },
      :vpcs => {
        :resource_title => "Amazon Virtual Private Clouds (VPCs)",
        :resource_type => :checkbox,
        :resource_id => :vpc_id,
        :resource_display_name => :vpc_id,
        :template_converter => "Vpcs",
        :template_section => :resources
      },
      :subnets => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) Subnets",
        :resource_type => :checkbox,
        :resource_id => :subnet_id,
        :resource_display_name => :subnet_id,
        :template_converter => "Subnets",
        :template_section => :resources
      },
      :igws => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) Internet Gateways",
        :resource_type => :checkbox,
        :resource_id => :internet_gateway_id,
        :resource_display_name => :internet_gateway_id,
        :template_converter => "Igws",
        :template_section => :resources
      },
      :cgws => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) Customer Gateways",
        :resource_type => :checkbox,
        :resource_id => :customer_gateway_id,
        :resource_display_name => :customer_gateway_id,
        :template_converter => "Cgws",
        :template_section => :resources
      },
      :vgws => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) VPN Gateways",
        :resource_type => :checkbox,
        :resource_id => :vpn_gateway_id,
        :resource_display_name => :vpn_gateway_id,
        :template_converter => "Vgws",
        :template_section => :resources
      },
      :vpn_connections => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) VPN Connections",
        :resource_type => :checkbox,
        :resource_id => :vpn_connection_id,
        :resource_display_name => :vpn_connection_id,
        :template_converter => "Vpn_connections",
        :template_section => :resources
      },
      :vpc_peers => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) Peering Connections",
        :resource_type => :checkbox,
        :resource_id => :vpc_peering_connection_id,
        :resource_display_name => :vpc_peering_connection_id,
        :template_converter => "VPC_Peers",
        :template_section => :resources
      },
      :gateway_attachments => {
        :resource_type => :hidden_resource,
        :template_converter => "Gateway_attachments",
        :template_section => :resources      
      },
      :network_acls => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) Network ACLs",
        :resource_type => :checkbox,
        :resource_id => :network_acl_id,
        :resource_display_name => :network_acl_id,
        :template_converter => "Network_acls",
        :template_section => :resources
      },
      :network_acl_entries => {
        :resource_type => :hidden_resource,
        :template_converter => "Network_acl_entries",
        :template_section => :resources      
      },
      :subnet_acl_associations => {
        :resource_type => :hidden_resource,
        :template_converter => "Subnet_acl_associations",
        :template_section => :resources      
      },
      :route_tables => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) Route Tables",
        :resource_type => :checkbox,
        :resource_id => :route_table_id,
        :resource_display_name => :route_table_id,
        :template_converter => "Route_tables",
        :template_section => :resources
      },
      :route_table_entries => {
        :resource_type => :hidden_resource,
        :template_converter => "Route_table_entries",
        :template_section => :resources      
      },
      :vpn_connection_routes => {
        :resource_type => :hidden_resource,
        :template_converter => "Vpn_connection_routes",
        :template_section => :resources      
      },
      :subnet_route_associations => {
        :resource_type => :hidden_resource,
        :template_converter => "Subnet_route_associations",
        :template_section => :resources      
      },
      :enis => {
        :resource_title => "Amazon EC2 Network Interfaces",
        :resource_type => :checkbox,
        :resource_id => :network_interface_id,
        :resource_display_name => :network_interface_id,
        :template_converter => "Enis",
        :template_section => :resources
      },
      :dhcps => {
        :resource_title => "Amazon Virtual Private Cloud (VPC) DHCP Options",
        :resource_type => :checkbox,
        :resource_id => :dhcp_options_id,
        :resource_display_name => :dhcp_options_id,
        :template_converter => "Dhcps",
        :template_section => :resources
      },
      :dhcp_associations => {
        :resource_type => :hidden_resource,
        :template_converter => "Dhcp_associations",
        :template_section => :resources      
      },
      :eips => {
        :resource_title => "Amazon EC2 Elastic IP Addresses",
        :resource_type => :checkbox,
        :resource_id => :public_ip,
        :resource_display_name => :public_ip,
        :template_converter => "Eips",
        :template_section => :resources
      },
      :elbs => {
        :resource_title => "Elastic Load Balancers",
        :resource_type => :checkbox,
        :resource_id => :load_balancer_name,
        :resource_display_name => :load_balancer_name,
        :template_converter => "Elbs",
        :template_section => :resources
      },
      :distributions => {
        :resource_title => "Amazon CloudFront Distributions",
        :resource_type => :checkbox,
        :resource_id => :domain_name,
        :resource_display_name => :domain_name,
        :template_converter => "Distributions",
        :template_section => :resources
      },
      :r53_recordsets => {
        :resource_title => "Route 53 DNS Records",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :target,
        :template_converter => "R53_Recordsets",
        :template_section => :resources
      },
      :r53_healthchecks => {
        :resource_title => "Route 53 Health Checks",
        :resource_type => :checkbox,
        :resource_id => :id,
        :resource_display_name => :id,
        :template_converter => "R53_Healthchecks",
        :template_section => :resources
      },
      :r53_hostedzones => {
        :resource_title => "Route 53 Hosted Zones",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "R53_Hostedzones",
        :template_section => :resources
      },
      :launch_configs => {
        :resource_title => "Auto Scaling Launch Configurations",
        :resource_type => :checkbox,
        :resource_id => :launch_configuration_name,
        :resource_display_name => :launch_configuration_name,
        :template_converter => "Launch_Configs",
        :template_section => :resources
      },
      :as_groups => {
        :resource_title => "Auto Scaling Groups",
        :resource_type => :checkbox,
        :resource_id => :auto_scaling_group_name,
        :resource_display_name => :auto_scaling_group_name,
        :template_converter => "AS_Groups",
        :template_section => :resources
      },
      :scheduled_actions => {
        :resource_title => "Auto Scaling Scheduled Actions",
        :resource_type => :checkbox,
        :resource_id => :scheduled_action_name,
        :resource_display_name => :scheduled_action_name,
        :template_converter => "Scheduled_actions",
        :template_section => :resources
      },
      :scaling_policies => {
        :resource_title => "Auto Scaling Policies",
        :resource_type => :checkbox,
        :resource_id => :policy_arn,
        :resource_display_name => :policy_arn,
        :template_converter => "Scaling_policies",
        :template_section => :resources
      },
      :eb_applications => {
        :resource_title => "Elastic Beanstalk Applications",
        :resource_type => :checkbox,
        :resource_id => :application_name,
        :resource_display_name => :application_name,
        :template_converter => "EB_Applications",
        :template_section => :resources
      },
      :eb_versions => {
        :resource_title => "Elastic Beanstalk Application Versions",
        :resource_type => :checkbox,
        :resource_id => :version_label,
        :resource_display_name => :version_label,
        :template_converter => "EB_Versions",
        :template_section => :resources
      },
      :eb_templates => {
        :resource_title => "Elastic Beanstalk Configuration Templates",
        :resource_type => :checkbox,
        :resource_id => :template_name,
        :resource_display_name => :template_name,
        :template_converter => "EB_Templates",
        :template_section => :resources
      },
      :eb_environments => {
        :resource_title => "Elastic Beanstalk Environments",
        :resource_type => :checkbox,
        :resource_id => :environment_name,
        :resource_display_name => :environment_name,
        :template_converter => "EB_Environments",
        :template_section => :resources
      },
      :opsworks_stacks => {
        :resource_title => "OpsWorks Stacks",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "OPSWORKS_Stacks",
        :template_section => :resources
      },
      :opsworks_layers => {
        :resource_title => "OpsWorks Layers",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "OPSWORKS_Layers",
        :template_section => :resources
      },
      :opsworks_instances => {
        :resource_title => "OpsWorks Instances",
        :resource_type => :checkbox,
        :resource_id => :instance_id,
        :resource_display_name => :hostname,
        :template_converter => "OPSWORKS_Instances",
        :template_section => :resources
      },
      :opsworks_elbs => {
        :resource_title => "OpsWorks Elastic Load Balancer Attachements",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "OPSWORKS_Elbs",
        :template_section => :resources
      },
      :opsworks_apps => {
        :resource_title => "OpsWorks Apps",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "OPSWORKS_Apps",
        :template_section => :resources
      },
      :alarms => {
        :resource_title => "CloudWatch Alarms",
        :resource_type => :checkbox,
        :resource_id => :alarm_name,
        :resource_display_name => :alarm_name,
        :template_converter => "Alarms",
        :template_section => :resources
      },
      :trails => {
        :resource_title => "CloudTrail Trails",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "Trails",
        :template_section => :resources
      },
      :instances => {
        :resource_title => "Amazon EC2 Instances",
        :resource_type => :checkbox,
        :resource_id => :instance_id,
        :resource_display_name => :instance_id,
        :template_converter => "Instances",
        :template_section => :resources
      },
      :security_groups => {
        :resource_title => "Amazon EC2 Security Groups",
        :resource_type => :checkbox,
        :resource_id => :fake_id,
        :resource_display_name => :group_name,
        :template_converter => "Security_Groups",
        :template_section => :resources      
      },
      :volumes => {
        :resource_title => "Amazon Elastic Block Storage Volumes",
        :resource_type => :checkbox,
        :resource_id => :volume_id,
        :resource_display_name => :volume_id,
        :template_converter => "Volumes",
        :template_section => :resources
      },
      :dbs => {
        :resource_title => "Amazon RDS Database Instances",
        :resource_type => :checkbox,
        :resource_id => :db_instance_identifier,
        :resource_display_name => :db_instance_identifier,
        :template_converter => "Databases",
        :template_section => :resources      
      },
      :db_security_groups => {
        :resource_title => "Amazon RDS Security Groups",
        :resource_type => :checkbox,
        :resource_id => :db_security_group_name,
        :resource_display_name => :db_security_group_name,
        :template_converter => "DB_Security_Groups",
        :template_section => :resources      
      },
      :db_subnet_groups => {
        :resource_title => "Amazon RDS DB Subnet Groups",
        :resource_type => :checkbox,
        :resource_id => :db_subnet_group_name,
        :resource_display_name => :db_subnet_group_name,
        :template_converter => "DB_Subnet_Groups",
        :template_section => :resources      
      },
      :db_parameter_groups => {
        :resource_title => "Amazon RDS DB Parameter Groups",
        :resource_type => :checkbox,
        :resource_id => :db_parameter_group_name,
        :resource_display_name => :db_parameter_group_name,
        :template_converter => "DB_Parameter_Groups",
        :template_section => :resources      
      },
      :caches => {
        :resource_title => "Amazon ElastiCache Cache Clusters",
        :resource_type => :checkbox,
        :resource_id => :cache_cluster_id,
        :resource_display_name => :cache_cluster_id,
        :template_converter => "Caches",
        :template_section => :resources      
      },
      :cache_security_groups => {
        :resource_title => "Amazon ElastiCache Security Groups",
        :resource_type => :checkbox,
        :resource_id => :cache_security_group_name,
        :resource_display_name => :cache_security_group_name,
        :template_converter => "Cache_Security_Groups",
        :template_section => :resources      
      },
      :cache_parameter_groups => {
        :resource_title => "Amazon ElastiCache Parameter Groups",
        :resource_type => :checkbox,
        :resource_id => :cache_parameter_group_name,
        :resource_display_name => :cache_parameter_group_name,
        :template_converter => "Cache_Parameter_Groups",
        :template_section => :resources      
      },
      :cachesecuritygroupingresses => {
        :resource_type => :hidden_resource,
        :template_converter => "Cache_Security_Group_Ingresses",
        :template_section => :resources      
      },
      :cache_subnet_groups => {
        :resource_title => "Amazon ElastiCache Subnet Groups",
        :resource_type => :checkbox,
        :resource_id => :cache_subnet_group_name,
        :resource_display_name => :cache_subnet_group_name,
        :template_converter => "Cache_Subnet_Groups",
        :template_section => :resources      
      },
      :redshift_clusters => {
        :resource_title => "Amazon Redshift Clusters",
        :resource_type => :checkbox,
        :resource_id => :cluster_identifier,
        :resource_display_name => :cluster_identifier,
        :template_converter => "REDSHIFT_Clusters",
        :template_section => :resources      
      },
      :redshift_parameter_groups => {
        :resource_title => "Amazon Redshift Cluster Parameter Groups",
        :resource_type => :checkbox,
        :resource_id => :parameter_group_name,
        :resource_display_name => :parameter_group_name,
        :template_converter => "REDSHIFT_Parameter_Groups",
        :template_section => :resources      
      },
      :redshift_subnet_groups => {
        :resource_title => "Amazon RedShift Cluster Subnet Groups",
        :resource_type => :checkbox,
        :resource_id => :cluster_subnet_group_name,
        :resource_display_name => :cluster_subnet_group_name,
        :template_converter => "REDSHIFT_Subnet_Groups",
        :template_section => :resources      
      },
      :redshift_security_groups => {
        :resource_title => "Amazon Redshift Cluster Security Groups",
        :resource_type => :checkbox,
        :resource_id => :cluster_security_group_name,
        :resource_display_name => :cluster_security_group_name,
        :template_converter => "REDSHIFT_Security_Groups",
        :template_section => :resources      
      },
      :redshiftsecuritygroupingresses => {
        :resource_type => :hidden_resource,
        :template_converter => "REDSHIFT_Security_Group_Ingresses",
        :template_section => :resources      
      },
      :queues => {
        :resource_title => "Amazon SQS Queues",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "Queues",
        :template_section => :resources      
      },
      :queue_policies => {
        :resource_title => "Amazon SQS Queue Policies",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :display_name,
        :template_converter => "Queue_Policies",
        :template_section => :resources      
      },
      :topics => {
        :resource_title => "Amazon SNS Topics",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "Topics",
        :template_section => :resources      
      },
      :topic_policies => {
        :resource_title => "Amazon SNS Topic Policies",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :display_name,
        :template_converter => "Topic_Policies",
        :template_section => :resources      
      },
      :domains => {
        :resource_title => "Amazon SimpleDB Domains",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :name,
        :template_converter => "Domains",
        :template_section => :resources      
      },
      :streams => {
        :resource_title => "Amazon Kinesis Streams",
        :resource_type => :checkbox,
        :resource_id => :stream_name,
        :resource_display_name => :stream_name,
        :template_converter => "Streams",
        :template_section => :resources      
      },
      :buckets => {
        :resource_title => "Amazon S3 Buckets",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :display_name,
        :template_converter => "Buckets",
        :template_section => :resources      
      },
      :bucket_policies => {
        :resource_title => "Amazon S3 Bucket Policies",
        :resource_type => :checkbox,
        :resource_id => :name,
        :resource_display_name => :display_name,
        :template_converter => "Bucket_Policies",
        :template_section => :resources      
      },
      :tables => {
        :resource_title => "Amazon DynamoDB Tables",
        :resource_type => :checkbox,
        :resource_id => :table_name,
        :resource_display_name => :table_name,
        :template_converter => "Tables",
        :template_section => :resources      
      },
      :triggers => {
        :resource_title => "Auto Scaling Triggers",
        :resource_type => :checkbox,
        :resource_id => :trigger_name,
        :resource_display_name => :trigger_name,
        :template_converter => "Triggers",
        :template_section => :resources      
      },
      :eipassociations => {
        :resource_type => :hidden_resource,
        :template_converter => "EIP_Associations",
        :template_section => :resources      
      },
      :eniattachments => {
        :resource_type => :hidden_resource,
        :template_converter => "ENI_Attachments",
        :template_section => :resources      
      },
      :securitygroupingresses => {
        :resource_type => :hidden_resource,
        :template_converter => "Security_Group_Ingresses",
        :template_section => :resources      
      },
      :securitygroupegresses => {
        :resource_type => :hidden_resource,
        :template_converter => "Security_Group_Egresses",
        :template_section => :resources      
      }
    }
  end
    
  def next_step
    self.current_step = steps[steps.index(current_step)+1]
  end

  def previous_step
    self.current_step = steps[steps.index(current_step)-1]
  end

  def first_step?
    self.current_step == steps.first
  end
  
  def last_step?
    self.current_step == steps.last
  end
  
  def summarize?
    self.current_step == "summary"
  end
  
end
