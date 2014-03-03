require 'spec_helper'

describe 'elasticsearch', :type => 'class' do

  [ 'Debian', 'Ubuntu'].each do |distro|

    context "on #{distro} OS" do

      let :facts do {
        :operatingsystem => distro,
        :kernel => 'Linux',
        :osfamily => 'Debian',
        :lsbdistid => distro.downcase
      } end

      context 'main class tests' do

        # init.pp
        it { should contain_anchor('elasticsearch::begin') }
        it { should contain_anchor('elasticsearch::end').that_requires('Class[elasticsearch::service]') }
        it { should contain_class('elasticsearch::params') }
        it { should contain_class('elasticsearch::package').that_requires('Anchor[elasticsearch::begin]') }
        it { should contain_class('elasticsearch::config').that_requires('Class[elasticsearch::package]') }
        it { should contain_class('elasticsearch::service').that_requires('Class[elasticsearch::package]').that_requires('Class[elasticsearch::config]') }

        # Base directories
        it { should contain_file('/etc/elasticsearch') }
        it { should contain_file('/etc/elasticsearch/elasticsearch.yml') }
        it { should contain_exec('mkdir_templates_elasticsearch').with(:command => 'mkdir -p /etc/elasticsearch/templates_import', :creates => '/etc/elasticsearch/templates_import') }
        it { should contain_file('/etc/elasticsearch/templates_import').with(:require => 'Exec[mkdir_templates_elasticsearch]') }
      end

      context 'package installation' do
        
        context 'via repository' do

          context 'with default settings' do
            
           it { should contain_package('elasticsearch').with(:ensure => 'present') }

          end

          context 'with specified version' do

            let :params do {
              :version => '1.0'
            } end

            it { should contain_package('elasticsearch').with(:ensure => '1.0') }
          end

          context 'with auto upgrade enabled' do

            let :params do {
              :autoupgrade => true
            } end

            it { should contain_package('elasticsearch').with(:ensure => 'latest') }
          end

        end

        context 'when setting package version and package_url' do

          let :params do {
            :version     => '0.90.10',
            :package_url => 'puppet:///path/to/some/elasticsearch-0.90.10.deb'
          } end

          it { expect { should raise_error(Puppet::Error) } }

        end

        context 'via package_url setting' do

          context 'using puppet:/// schema' do

            let :params do {
              :package_url => 'puppet:///path/to/package.deb'
            } end

            it { should contain_file('/opt/elasticsearch/swdl/package.deb').with(:source => 'puppet:///path/to/package.deb', :backup => false) }
            it { should contain_package('elasticsearch').with(:ensure => 'present', :source => '/opt/elasticsearch/swdl/package.deb', :provider => 'dpkg') }
          end

          context 'using http:// schema' do

            let :params do {
              :package_url => 'http://www.domain.com/path/to/package.deb'
            } end

            it { should contain_exec('create_package_dir_elasticsearch').with(:command => 'mkdir -p /opt/elasticsearch/swdl') }
            it { should contain_file('/opt/elasticsearch/swdl').with(:purge => false, :force => false, :require => "Exec[create_package_dir_elasticsearch]") }
            it { should contain_exec('download_package_elasticsearch').with(:command => 'wget -O /opt/elasticsearch/swdl/package.deb http://www.domain.com/path/to/package.deb 2> /dev/null', :require => 'File[/opt/elasticsearch/swdl]') }
            it { should contain_package('elasticsearch').with(:ensure => 'present', :source => '/opt/elasticsearch/swdl/package.deb', :provider => 'dpkg') }
          end

          context 'using https:// schema' do

            let :params do {
              :package_url => 'https://www.domain.com/path/to/package.deb'
            } end

            it { should contain_exec('create_package_dir_elasticsearch').with(:command => 'mkdir -p /opt/elasticsearch/swdl') }
            it { should contain_file('/opt/elasticsearch/swdl').with(:purge => false, :force => false, :require => 'Exec[create_package_dir_elasticsearch]') }
            it { should contain_exec('download_package_elasticsearch').with(:command => 'wget -O /opt/elasticsearch/swdl/package.deb https://www.domain.com/path/to/package.deb 2> /dev/null', :require => 'File[/opt/elasticsearch/swdl]') }
            it { should contain_package('elasticsearch').with(:ensure => 'present', :source => '/opt/elasticsearch/swdl/package.deb', :provider => 'dpkg') }
          end

          context 'using ftp:// schema' do

            let :params do {
              :package_url => 'ftp://www.domain.com/path/to/package.deb'
            } end

            it { should contain_exec('create_package_dir_elasticsearch').with(:command => 'mkdir -p /opt/elasticsearch/swdl') }
            it { should contain_file('/opt/elasticsearch/swdl').with(:purge => false, :force => false, :require => 'Exec[create_package_dir_elasticsearch]') }
            it { should contain_exec('download_package_elasticsearch').with(:command => 'wget -O /opt/elasticsearch/swdl/package.deb ftp://www.domain.com/path/to/package.deb 2> /dev/null', :require => 'File[/opt/elasticsearch/swdl]') }
            it { should contain_package('elasticsearch').with(:ensure => 'present', :source => '/opt/elasticsearch/swdl/package.deb', :provider => 'dpkg') }
          end

          context 'using file:// schema' do

            let :params do {
              :package_url => 'file:/path/to/package.deb'
            } end

            it { should contain_exec('create_package_dir_elasticsearch').with(:command => 'mkdir -p /opt/elasticsearch/swdl') }
            it { should contain_file('/opt/elasticsearch/swdl').with(:purge => false, :force => false, :require => 'Exec[create_package_dir_elasticsearch]') }
            it { should contain_file('/opt/elasticsearch/swdl/package.deb').with(:source => '/path/to/package.deb', :backup => false) }
            it { should contain_package('elasticsearch').with(:ensure => 'present', :source => '/opt/elasticsearch/swdl/package.deb', :provider => 'dpkg') }
          end

        end

      end # package

      context 'service setup' do

        context 'with provider \'init\'' do

          it { should contain_elasticsearch__service__init('elasticsearch') }

          context 'and default settings' do

            it { should contain_service('elasticsearch').with(:ensure => 'running') }

          end

          context 'and set defaults via hash param' do

            let :params do {
              :init_defaults => { 'ES_USER' => 'root', 'ES_GROUP' => 'root' }
            } end

            it { should contain_augeas('defaults_elasticsearch').with(:notify => 'Service[elasticsearch]', :incl => '/etc/default/elasticsearch', :changes => "set ES_GROUP root\nset ES_USER root\n") }

          end

          context 'and set defaults via file param' do

            let :params do {
              :init_defaults_file => 'puppet:///path/to/elasticsearch.defaults'
            } end

            it { should contain_file('/etc/default/elasticsearch').with(:source => 'puppet:///path/to/elasticsearch.defaults', :notify => 'Service[elasticsearch]') }

          end

          context 'no service restart when defaults change' do

           let :params do {
              :init_defaults     => { 'ES_USER' => 'root', 'ES_GROUP' => 'root' },
              :restart_on_change => false
            } end

            it { should contain_augeas('defaults_elasticsearch').with(:incl => '/etc/default/elasticsearch', :changes => "set ES_GROUP root\nset ES_USER root\n").without_notify }

          end 

          context 'and set init file via template' do

            let :params do {
              :init_template => "elasticsearch/etc/init.d/elasticsearch.Debian.erb"
            } end

            it { should contain_file('/etc/init.d/elasticsearch').with(:notify => 'Service[elasticsearch]') }

          end

          context 'No service restart when restart_on_change is false' do

            let :params do {
              :init_template     => "elasticsearch/etc/init.d/elasticsearch.Debian.erb",
              :restart_on_change => false
            } end

            it { should contain_file('/etc/init.d/elasticsearch').without_notify }

          end

          context 'when its unmanaged do nothing with it' do

            let :params do {
              :status => 'unmanaged'
            } end

            it { should contain_service('elasticsearch').with(:ensure => nil, :enable => false) }

          end

        end # provider init

      end # Services

      context 'when setting the module to absent' do

         let :params do {
           :ensure => 'absent'
         } end

         it { should contain_file('/etc/elasticsearch').with(:ensure => 'absent', :force => true, :recurse => true) }
         it { should contain_package('elasticsearch').with(:ensure => 'purged') }
         it { should contain_service('elasticsearch').with(:ensure => 'stopped', :enable => false) }

      end

      context 'When managing the repository' do

        let :params do {
          :manage_repo => true,
          :repo_version => '1.0'
        } end

        it { should contain_class('elasticsearch::repo').that_requires('Anchor[elasticsearch::begin]') }
        it { should contain_class('apt') }
        it { should contain_apt__source('elasticsearch').with(:release => 'stable', :repos => 'main', :location => 'http://packages.elasticsearch.org/elasticsearch/1.0/debian') }

      end

    end

  end

end
