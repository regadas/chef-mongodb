
require 'chef/node'

class Chef::ResourceDefinitionList::OpsWorksHelper

  # true if we're on opsworks, false otherwise
  def self.opsworks?(node)
    node['opsworks'] != nil
  end

  def self.instance(node)
    node['opsworks']['instance']
  end

  def self.hostname(node)
    self.instance(node)['hostname']
  end

  def self.stack_layer(node)
    self.instance(node)['layers'].first
  end

  def self.instance_data_bag(node, name)
    layer = self.stack_layer(node)
    node['opsworks'].fetch('data_bags', {}).fetch(layer, {}).fetch(name, {})
  end

  def self.data_bag(node)
    name = self.hostname(node)
    self.instance_data_bag(node, name)
  end

  # return Chef Nodes for this replicaset / layer
  def self.replicaset_members(node)
    Chef::Log.info('OpsWorks replicaset members')

    members = []
    # FIXME -> this is bad, we're assuming replicaset instances use a single layer
    replicaset_layer_slug_name = self.stack_layer(node)
    instances = node['opsworks']['layers'][replicaset_layer_slug_name]['instances']
    instances.each do |name, instance|
      if instance['status'] == 'online'
        member = Chef::Node.new
        member.name(name)
        member.default['fqdn'] = instance['private_dns_name']
        member.default['ipaddress'] = instance['private_ip']
        member.default['hostname'] = name
        bag_conf = node['opsworks']['data_bags']['mongodb'][name]
        mongodb_attributes = {
          # here we could support a map of instances to custom replicaset options in the custom json
          'port' => node['mongodb']['config']['port'],
          'replica_arbiter_only' => bag_conf['mongodb']['replica_arbiter_only'] || false,
          'replica_build_indexes' => bag_conf['mongodb']['replica_build_indexes'] || true,
          'replica_hidden' => bag_conf['mongodb']['replica_hidden'] || false,
          'replica_slave_delay' => bag_conf['mongodb']['replica_slave_delay'] || 0,
          'replica_priority' => bag_conf['mongodb']['replica_priority'] || 1,
          'replica_tags' => bag_conf['mongodb']['replica_parbiter_only'] || {}, # to_hash is called on this
          'replica_votes' => bag_conf['mongodb']['replica_votes'] || 1
        }
        member.default['mongodb'] = mongodb_attributes
        members << member
      end
    end
    members
  end

end
