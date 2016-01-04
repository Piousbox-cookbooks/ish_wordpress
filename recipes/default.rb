#
# Cookbook Name:: ish_wordpress
# Recipe:: default
#
# Copyright 2016, wasya.co
#
# All rights reserved - Do Not Redistribute
#

%w{ ruby-dev }.each do |pkg|
  package pkg
end

app = data_bag_item('apps', node['apache2']['wp_site'])
node['wordpress']['dir'] = app['document_root'][node.chef_environment]
node['wordpress']['db']['root_password'] = app['databases'][node.chef_environment]['password']
node['wordpress']['db']['name'] = app['databases'][node.chef_environment]['database']
node['wordpress']['db']['user'] = app['databases'][node.chef_environment]['username']
node['wordpress']['db']['pass'] = app['databases'][node.chef_environment]['password']
node['wordpress']['db']['host'] = app['databases'][node.chef_environment]['host']

include_recipe "wordpress::default"








