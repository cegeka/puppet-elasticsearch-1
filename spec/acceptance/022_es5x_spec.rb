require 'spec_helper_acceptance'

describe 'elasticsearch 5.x' do
  # Java 8 is only easy to manage on recent distros
  if fact('osfamily') == 'RedHat' or fact('lsbdistcodename') == 'xenial'
    # On CentOS/RedHat 7, we can just trust packages of java are recent
    if fact('operatingsystemmajrelease') == '7'
      java_install = true
    else
      # Otherwise, grab the Oracle JRE 8 package
      java_install = false
      java_snippet = <<-EOS
        java::oracle { 'jre8':
          java_se => 'jre',
        }
      EOS
    end

    describe 'manifest' do
      pp = <<-EOS
        class { 'elasticsearch':
          config => {
            'node.name' => 'elasticsearch001',
            'cluster.name' => '#{test_settings['cluster_name']}',
            'network.host' => '0.0.0.0',
          },
          manage_repo => true,
          repo_version => '#{test_settings['repo_version5x']}',
          java_install => #{java_install},
          version => '5.0.0',
          restart_on_change => true,
        }

        elasticsearch::instance { 'es-01':
          config => {
            'node.name' => 'elasticsearch001',
            'http.port' => '#{test_settings['port_a']}'
          }
        }
      EOS
      if not java_install
        pp = java_snippet + '->' + pp
      end

      it 'applies cleanly' do
        apply_manifest pp, :catch_failures => true
      end
      it 'is idempotent' do
        apply_manifest pp , :catch_changes  => true
      end
    end

    describe port(test_settings['port_a']) do
      it 'open', :with_retries do should be_listening end
    end

    describe server :container do
      describe http "http://localhost:#{test_settings['port_a']}" do
        it 'reports ES as upgraded', :with_retries do
          expect(
            JSON.parse(response.body)['version']['number']
          ).to eq('5.0.0')
        end
      end
    end
  else
    describe 'unsupported' do
      pending 'testing on distribution'
    end
  end
end
